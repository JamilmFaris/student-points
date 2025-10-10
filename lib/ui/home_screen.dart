import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
	const HomeScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Directionality(
			textDirection: TextDirection.rtl,
			child: Scaffold(
				appBar: AppBar(title: Center(child: const Text('السلام عليكم ورحمة الله'))),
				body: SafeArea(
					child: LayoutBuilder(
						builder: (context, constraints) {
							final isWide = constraints.maxWidth >= 600;
							final crossAxisCount = isWide ? 3 : 2;
							return Padding(
								padding: const EdgeInsets.all(16),
								child: GridView.count(
									crossAxisCount: crossAxisCount,
									mainAxisSpacing: 16,
									crossAxisSpacing: 16,
									children: [
										_ActionCard(
											label: 'الطلاب',
											icon: Icons.people,
											onTap: () => Navigator.pushNamed(context, '/students'),
										),
										_ActionCard(
											label: 'العادات',
											icon: Icons.fact_check,
											onTap: () => Navigator.pushNamed(context, '/habits'),
										),
										_ActionCard(
											label: 'تتبع النقاط لليوم',
											icon: Icons.today,
											onTap: () => Navigator.pushNamed(context, '/tracking'),
										),
										_ActionCard(
											label: 'سجل النقاط',
											icon: Icons.history,
											onTap: () => Navigator.pushNamed(context, '/logs'),
										),
							_ActionCard(
								label: 'حفظ القرآن',
								icon: Icons.menu_book,
								onTap: () => Navigator.pushNamed(context, '/quran'),
							),
									],
								),
							);
						},
					),
				),
			),
		);
	}
}

class _ActionCard extends StatelessWidget {
	final String label;
	final IconData icon;
	final VoidCallback onTap;

	const _ActionCard({required this.label, required this.icon, required this.onTap});

	@override
	Widget build(BuildContext context) {
		final color = Theme.of(context).colorScheme;
		return Card(
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
			elevation: 2,
			child: InkWell(
				borderRadius: BorderRadius.circular(16),
				onTap: onTap,
				child: Padding(
					padding: const EdgeInsets.all(20),
					child: Column(
						mainAxisAlignment: MainAxisAlignment.center,
						children: [
							Icon(icon, size: 36, color: color.primary),
							const SizedBox(height: 12),
							Text(
								label,
								textAlign: TextAlign.center,
								style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
							),
						],
					),
				),
			),
		);
	}
}


