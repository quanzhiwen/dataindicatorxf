// 构建期使用的 Preferences 私有框架符号存根（仅用于链接，不随 deb 发布）。
// CI 会把它编译成 Preferences.framework/Preferences（install_name 指向系统
// 私有框架路径），链接期满足 -framework Preferences 的符号检查；
// 运行时 dyld 按 install_name 从系统共享缓存加载真正的 Preferences 框架。
void *DIXFStubPSListController __asm__("OBJC_CLASS_$_PSListController") = 0;
void *DIXFStubPSListControllerMeta __asm__("OBJC_METACLASS_$_PSListController") = 0;
void *DIXFStubPSViewController __asm__("OBJC_CLASS_$_PSViewController") = 0;
void *DIXFStubPSViewControllerMeta __asm__("OBJC_METACLASS_$_PSViewController") = 0;
void *DIXFStubPSSpecifier __asm__("OBJC_CLASS_$_PSSpecifier") = 0;
void *DIXFStubPSSpecifierMeta __asm__("OBJC_METACLASS_$_PSSpecifier") = 0;
void *DIXFStubPSGroupSpecifier __asm__("OBJC_CLASS_$_PSGroupSpecifier") = 0;
void *DIXFStubPSGroupSpecifierMeta __asm__("OBJC_METACLASS_$_PSGroupSpecifier") = 0;
