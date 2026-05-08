---
name: Backend changes required for Flutter sync integration
overview: >
  The Flutter app needs single-device session enforcement, delta sync via updated_at,
  a batch overwrite endpoint for daily student points, dated attendance, full CRUD on
  the resources the app can edit, and a "current user" endpoint. Implement the items
  below; existing endpoint shapes and naming should be preserved unless noted.
---

## 0. Conventions

- All timestamps are UTC, ISO-8601 (`date-time`).
- Every change must be reflected in the OpenAPI schema (`/api/schema/`).
- Keep existing field names and casing (the schema currently mixes `snake_case` with `minusPoints`/`isMinus`/`studentId` — preserve those for backward compatibility).

## 1. `updated_at` on every sync resource

Add an auto-managed `updated_at` (`DateTimeField(auto_now=True)`) field to:

- `Student`
- `Habit`
- `Lesson`
- `Attendance`
- `StudentPoints`
- `StudentHifz`

Expose it as **read-only** in every serializer.

### `?updated_since=` filter

For each list endpoint below, accept a query parameter `updated_since` (ISO-8601 UTC). When present, return only rows with `updated_at > updated_since`:

- `GET /api/students/`
- `GET /api/habits/`
- `GET /api/lessons/`
- `GET /api/student-points/`
- `GET /api/quran/hifz/`
- `GET /api/lessons/attendances` and `GET /api/lessons/{lesson_id}/attendances`

Document the parameter in the OpenAPI schema for each endpoint.

## 2. Soft delete (tombstones)

The client needs to know when a row was deleted on the server so it can remove its local copy during delta sync.

- Add `is_deleted` (boolean, default `false`) and rely on `updated_at` for the deletion time on all resources from §1.
- Override `destroy()` on the relevant viewsets to set `is_deleted=True` and bump `updated_at` instead of hard-deleting.
- List endpoints **without** `updated_since` must exclude `is_deleted=True` rows (so a fresh full-pull sees only live data).
- List endpoints **with** `updated_since` must **include** `is_deleted=True` rows so the client can prune them locally.
- Expose `is_deleted` as a read-only field in serializers.

## 3. Single-device session policy

Goal: a successful login on Device B invalidates Device A's tokens.

Pick the simpler approach:

- Add `token_version` (PositiveIntegerField, default 0) on the user model.
- On every successful `POST /api/auth/login/`, increment `token_version` and embed the new value as a custom claim (`token_version`) in both the access and refresh tokens.
- Write a custom JWT authentication class (subclass `JWTAuthentication`) that, after decoding, compares the token's `token_version` claim against the user's current `token_version`. On mismatch, raise `InvalidToken` with code `token_not_valid` (so the client's existing 401 handling kicks in).
- Apply the same check inside the refresh endpoint (`POST /api/auth/login/refresh/`) — refresh must fail if the version doesn't match.

No new endpoints are required.

## 4. `GET /api/users/me/`

Return the authenticated user's profile so the client can store it after login.

- New endpoint: `GET /api/users/me/`, JWT-required.
- Response schema: same as `UserCreate` minus `password`, plus `id`.
- Add to the OpenAPI schema under tag `Users`.

## 5. Batch endpoint for daily student points (overwrite semantics)

The current `POST /api/student-points/` is append-only and computes `points` from the habit. The client needs to send **absolute totals per (student, habit, day)** so re-syncs are idempotent.

### New endpoint

`POST /api/student-points/batch/` (JWT required, teacher-scoped)

Request body:

```json
{
  "date": "2026-05-02",
  "lesson_id": 12,
  "entries": [
    {"student_id": 5, "habit_id": 2, "plus_count": 3, "minus_count": 1},
    {"student_id": 6, "habit_id": 2, "plus_count": 0, "minus_count": 2}
  ]
}
```

- `date` is the calendar day (UTC) the totals apply to.
- `plus_count` / `minus_count` are absolute counts for that day (not deltas).
- `lesson_id` is optional metadata; include it only if `StudentPoints` gains a `lesson` FK (recommended — see below).

### Server behavior

Inside a single transaction, for each entry:

1. Delete all existing `StudentPoints` rows for `(teacher=request.user, student=student_id, habit=habit_id, created_at__date=date)`.
2. Insert `plus_count` rows with `isMinus=false` and `minus_count` rows with `isMinus=true`, all stamped with `created_at = <date>T12:00:00Z` (or any deterministic time inside that day).
3. The existing `points` computation on `StudentPoints` continues to work unchanged.

### Schema changes

- Add an optional `lesson` FK on `StudentPoints` (nullable, on_delete=SET_NULL). Expose as `lesson` (integer, nullable) in the serializer.
- Document the new endpoint and request/response in the OpenAPI schema.

Response: `201` with `{"written": <int>, "deleted": <int>}`.

## 6. Attendance with dates

Attendance is currently `{student, attended}` per lesson with no date — re-marking the same lesson on a different day overwrites history. The client needs daily attendance.

### Model changes

- Add `date` (DateField, indexed) to `Attendance`.
- Add `(lesson, student, date)` unique constraint.
- The existing `(lesson, student)` unique constraint (if any) must be removed.

### Endpoint changes

- `GET /api/lessons/{lesson_id}/attendances?date=YYYY-MM-DD` — returns roster for that lesson on that date. If `date` omitted, default to today (UTC).
- `POST /api/lessons/{lesson_id}/attendances` — request body gains a top-level `date` (required). Existing `students: [{studentId}]` array remains. Server upserts on `(lesson, student, date)` and sets `attended=true` for every student in the payload. Students for that lesson+date **not** in the payload are set to `attended=false` (so the payload is the source of truth for the day).
- Add `date` to the `Attendance` response serializer.
- Update `BulkAttendancePayload` and `AttendanceListResponse` schemas accordingly.

## 7. Full CRUD on editable resources

Add the missing endpoints below. All teacher-scoped, JWT required, and respecting soft delete from §2.

### Lessons

- `GET /api/lessons/{id}/`
- `PUT /api/lessons/{id}/`
- `PATCH /api/lessons/{id}/`
- `DELETE /api/lessons/{id}/` (soft delete)

### StudentPoints

- `DELETE /api/student-points/{id}/` (soft delete) — used only for ad-hoc corrections; the batch endpoint handles the common case.

### Hifz

- `GET /api/quran/hifz/{id}/`
- `PUT /api/quran/hifz/{id}/`
- `PATCH /api/quran/hifz/{id}/`
- `DELETE /api/quran/hifz/{id}/` (soft delete)

## 8. Migration & deployment notes

- Generate one migration per model change. `updated_at` with `auto_now=True` will populate on next save; backfill existing rows with a data migration that sets `updated_at = created_at` (or `now()` for models without `created_at`).
- `Attendance.date` backfill: set to `created_at::date` if a `created_at` exists, otherwise to the current date — discuss with product before running.
- `User.token_version` defaults to 0; existing tokens will all carry the absent/zero claim and remain valid until next login. Document this so QA expects one "free" session per user post-deploy.

## 9. Out of scope (explicitly)

- Conflict resolution UI / merge endpoints — single-device policy makes this unnecessary.
- Push notifications for cross-device logout.
- Per-field auditing.
