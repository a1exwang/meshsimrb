#include "ruby.h"

VALUE Fast4DMatrix = Qnil;
VALUE Vec3 = Qnil;
VALUE Matrix4Sym = Qnil;

// method declarations
void Init_fast_4d_matrix();
VALUE Vec3_method_initialize(VALUE self, VALUE rbx, VALUE rby, VALUE rbz);
VALUE Vec3_method_to_a(VALUE self);

VALUE Matrix4Sym_class_method_zero(VALUE clazz);
VALUE Matrix4Sym_class_method_from_vec4(VALUE clazz, VALUE a, VALUE b, VALUE c, VALUE d);
VALUE Matrix4Sym_class_method_from_face(VALUE clazz, VALUE v1, VALUE v2, VALUE v3);
VALUE Matrix4Sym_method_to_a(VALUE self);

void Init_fast_4d_matrix() {
	Fast4DMatrix = rb_define_module("Fast4DMatrix");

	Vec3 = rb_define_class_under(Fast4DMatrix, "Vec3", rb_cObject);
	rb_define_method(Vec3, "initialize", Vec3_method_initialize, 3);
	rb_define_method(Vec3, "to_a", Vec3_method_to_a, 0);

	Matrix4Sym = rb_define_class_under(Fast4DMatrix, "Matrix4Sym", rb_cObject);
	rb_define_singleton_method(Matrix4Sym, "zero", Matrix4Sym_class_method_zero, 0);
	rb_define_singleton_method(Matrix4Sym, "from_vec4", Matrix4Sym_class_method_from_vec4, 4);
	rb_define_singleton_method(Matrix4Sym, "from_face", Matrix4Sym_class_method_from_face, 3);
	rb_define_method(Matrix4Sym, "to_a", Matrix4Sym_method_to_a, 0);
}

typedef struct TVec3Type {
    double values[3];
} Vec3Type;

VALUE Vec3_method_initialize(VALUE self, VALUE rbx, VALUE rby, VALUE rbz) {
    Vec3Type *v = malloc(sizeof(Vec3Type));
    v->values[0] = RFLOAT_VALUE(rbx);
    v->values[1] = RFLOAT_VALUE(rby);
    v->values[2] = RFLOAT_VALUE(rbz);
    VALUE vec3DataObj = Data_Wrap_Struct(rb_cObject, 0, free, v);
    VALUE idVec3DataObj = rb_intern("vec3_data_obj");
    rb_ivar_set(self, idVec3DataObj, vec3DataObj);
    return Qnil;
}

VALUE Vec3_method_to_a(VALUE self) {
    Vec3Type *v;

    VALUE idVec3DataObj = rb_intern("vec3_data_obj");
    VALUE rbVec3DataObj = rb_ivar_get(self, idVec3DataObj);

    Data_Get_Struct(rbVec3DataObj, Vec3Type, v);

    VALUE ret = rb_ary_new();
    rb_ary_push(ret, rb_float_new(v->values[0]));
    rb_ary_push(ret, rb_float_new(v->values[1]));
    rb_ary_push(ret, rb_float_new(v->values[2]));

    return ret;
}

#define TMatrix4SymType_KPS_COUNT 16
typedef struct TMatrix4SymType {
    double kps[TMatrix4SymType_KPS_COUNT];
} Matrix4SymType;

VALUE Matrix4Sym_class_method_zero(VALUE clazz) {
    VALUE idNew = rb_intern("new");
    VALUE obj = rb_funcall(clazz, idNew, 0);

    Matrix4SymType *v = malloc(sizeof(Matrix4SymType));
    for (int i = 0; i < TMatrix4SymType_KPS_COUNT; ++i)
        v->kps[i] = 0;
    VALUE matDataObject = Data_Wrap_Struct(rb_cObject, 0, free, v);
    VALUE idMatDataObj = rb_intern("mat_data_obj");
    rb_ivar_set(obj, idMatDataObj, matDataObject);
    return obj;
}

VALUE Matrix4Sym_class_method_from_vec4(VALUE clazz, VALUE aa, VALUE bb, VALUE cc, VALUE dd) {
    VALUE idNew = rb_intern("new");
    VALUE obj = rb_funcall(clazz, idNew, 0);

    double a = RFLOAT_VALUE(aa);
    double b = RFLOAT_VALUE(bb);
    double c = RFLOAT_VALUE(cc);
    double d = RFLOAT_VALUE(dd);

    Matrix4SymType *v = malloc(sizeof(Matrix4SymType));

    v->kps[0] =  a * a; v->kps[1] =  b * a; v->kps[2] =  c * a; v->kps[3] =  d * a;
    v->kps[4] =  a * b; v->kps[5] =  b * b; v->kps[6] =  c * b; v->kps[7] =  d * b;
    v->kps[8] =  a * c; v->kps[9] =  b * c; v->kps[10] = c * c; v->kps[11] = d * c;
    v->kps[12] = a * d; v->kps[13] = b * d; v->kps[14] = c * d; v->kps[15] = d * d;


    VALUE matDataObject = Data_Wrap_Struct(rb_cObject, 0, free, v);
    VALUE idMatDataObj = rb_intern("mat_data_obj");
    rb_ivar_set(obj, idMatDataObj, matDataObject);
    return obj;
}

VALUE Matrix4Sym_class_method_from_face(VALUE clazz, VALUE v1, VALUE v2, VALUE v3) {
    VALUE idNew = rb_intern("new");
    VALUE obj = rb_funcall(clazz, idNew, 0);



    double a = 0;
    double b = 0;
    double c = 0;
    double d = 1;

    Matrix4SymType *v = malloc(sizeof(Matrix4SymType));

    v->kps[0] =  a * a; v->kps[1] =  b * a; v->kps[2] =  c * a; v->kps[3] =  d * a;
    v->kps[4] =  a * b; v->kps[5] =  b * b; v->kps[6] =  c * b; v->kps[7] =  d * b;
    v->kps[8] =  a * c; v->kps[9] =  b * c; v->kps[10] = c * c; v->kps[11] = d * c;
    v->kps[12] = a * d; v->kps[13] = b * d; v->kps[14] = c * d; v->kps[15] = d * d;

    VALUE matDataObject = Data_Wrap_Struct(rb_cObject, 0, free, v);
    VALUE idMatDataObj = rb_intern("mat_data_obj");
    rb_ivar_set(obj, idMatDataObj, matDataObject);
    return obj;
}

VALUE Matrix4Sym_method_to_a(VALUE self) {
    VALUE idMatDataObj = rb_intern("mat_data_obj");
    VALUE matDataObject = rb_ivar_get(self, idMatDataObj);
    Matrix4SymType *v;
    Data_Get_Struct(matDataObject, Matrix4SymType, v);

    VALUE ret = rb_ary_new();
    for (int i = 0; i < 4; ++i) {
        VALUE lineAry = rb_ary_new();
        for (int j = 0; j < 4; ++j) {
            rb_ary_push(lineAry, rb_float_new(v->kps[i * 4 + j]));
        }
        rb_ary_push(ret, lineAry);
    }

    return ret;
}

