class A {
  String? a;
}

mixin B {
  bool get hey => true;
}

class C extends A with B {
  int? stuff;
}

C cDeclaration = C();
