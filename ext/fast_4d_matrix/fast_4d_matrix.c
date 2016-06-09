// Include the Ruby headers and goodies
#include "ruby.h"

// Defining a space for information and references about the module to be stored internally
VALUE Fast4DMatrix = Qnil;

// Prototype for the initialization method - Ruby calls this, not you
void Init_fast_4d_matrix();

// Prototype for our method 'test1' - methods are prefixed by 'method_' here
VALUE method_get_value(VALUE self);

// The initialization method for this module
void Init_fast_4d_matrix() {
	Fast4DMatrix = rb_define_module("Fast4DMatrix");
	rb_define_method(Fast4DMatrix, "get_value", method_get_value, 0);
}

// Our 'test1' method.. it simply returns a value of '10' for now.
VALUE method_get_value(VALUE self) {
	int x = 10;
	return INT2NUM(x);
}