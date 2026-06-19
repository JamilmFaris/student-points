import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/auth_cubit.dart';

class AppDrawer extends StatelessWidget {
	const AppDrawer({super.key});

	@override
	Widget build(BuildContext context) {
		final authCubit = context.read<AuthCubit>();
		final user = context.select<AuthCubit, String?>((c) => c.state.user?.displayName);
		return Directionality(
			textDirection: TextDirection.rtl,
			child: Drawer(
				child: SafeArea(
					child: ListView(
						padding: EdgeInsets.zero,
						children: [
							DrawerHeader(
								decoration: const BoxDecoration(color: Colors.teal),
								child: Align(
									alignment: AlignmentDirectional.centerStart,
									child: Column(
										mainAxisAlignment: MainAxisAlignment.end,
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('نقاط الطلاب', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
											if (user != null) ...[
												const SizedBox(height: 6),
												Text(user, style: const TextStyle(color: Colors.white70, fontSize: 13)),
											],
										],
									),
								),
							),
							_ListItem(icon: Icons.home, label: 'الرئيسية', routeName: '/home'),
							_ListItem(icon: Icons.people, label: 'الطلاب', routeName: '/students'),
							_ListItem(icon: Icons.fact_check, label: 'العادات', routeName: '/habits'),
							_ListItem(icon: Icons.today, label: 'تتبع النقاط لليوم', routeName: '/tracking'),
							_ListItem(icon: Icons.history, label: 'سجل النقاط', routeName: '/logs'),
							_ListItem(icon: Icons.menu_book, label: 'الحفظ والسبر', routeName: '/quran'),
							const Divider(),
							_ListItem(icon: Icons.person, label: 'الملف الشخصي', routeName: '/profile'),
							_ListItem(icon: Icons.settings, label: 'الإعدادات', routeName: '/settings'),
							ListTile(
								leading: const Icon(Icons.logout, color: Colors.redAccent),
								title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent)),
								onTap: () async {
									Navigator.pop(context);
									await authCubit.logout();
									if (context.mounted) {
										Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
									}
								},
							),
						],
					),
				),
			),
		);
	}
}

class _ListItem extends StatelessWidget {
	final IconData icon;
	final String label;
	final String routeName;

	const _ListItem({required this.icon, required this.label, required this.routeName});

	@override
	Widget build(BuildContext context) {
		return ListTile(
			leading: Icon(icon),
			title: Text(label),
			onTap: () {
				Navigator.pop(context);
				if (routeName == '/home') {
					// Pop all pushed routes back to the root HomeScreen
					// instead of stacking another /home on top.
					Navigator.popUntil(context, (route) => route.isFirst);
				} else {
					Navigator.pushNamed(context, routeName);
				}
			},
		);
	}
}








