import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
	const AppDrawer({super.key});

	@override
	Widget build(BuildContext context) {
		return Directionality(
			textDirection: TextDirection.rtl,
			child: Drawer(
				child: SafeArea(
					child: ListView(
						padding: EdgeInsets.zero,
						children: [
							const DrawerHeader(
								decoration: BoxDecoration(color: Colors.teal),
								child: Align(
									alignment: AlignmentDirectional.centerStart,
									child: Text('نقاط الطلاب', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
								),
							),
							_ListItem(icon: Icons.home, label: 'الرئيسية', routeName: '/'),
							_ListItem(icon: Icons.people, label: 'الطلاب', routeName: '/students'),
							_ListItem(icon: Icons.fact_check, label: 'العادات', routeName: '/habits'),
							_ListItem(icon: Icons.today, label: 'تتبع النقاط لليوم', routeName: '/tracking'),
							_ListItem(icon: Icons.history, label: 'سجل النقاط', routeName: '/logs'),
							_ListItem(icon: Icons.menu_book, label: 'حفظ القرآن', routeName: '/quran'),
							const Divider(),
							_ListItem(icon: Icons.settings, label: 'الإعدادات', routeName: '/settings'),
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
				Navigator.pushNamed(context, routeName);
			},
		);
	}
}


