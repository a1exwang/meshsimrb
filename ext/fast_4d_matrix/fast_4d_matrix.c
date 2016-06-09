#include "ruby.h"
#include <math.h>

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
VALUE Matrix4Sym_method_delta(VALUE self, VALUE vec);
VALUE Matrix4Sym_method_add_bang(VALUE self, VALUE other);

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
	rb_define_method(Matrix4Sym, "delta", Matrix4Sym_method_delta, 1);
	rb_define_method(Matrix4Sym, "add!", Matrix4Sym_method_add_bang, 1);
}

typedef struct TVec3Type {
    double values[3];
    double moreValues[9];
} Vec3Type;

VALUE Vec3_method_initialize(VALUE self, VALUE rbx, VALUE rby, VALUE rbz) {
    Vec3Type *v = malloc(sizeof(Vec3Type));
    double x, y, z;
    v->values[0] = x = RFLOAT_VALUE(rbx);
    v->values[1] = y = RFLOAT_VALUE(rby);
    v->values[2] = z = RFLOAT_VALUE(rbz);
    v->moreValues[0] = x * x;
    v->moreValues[1] = y * y;
    v->moreValues[2] = z * z;
    v->moreValues[3] = x * y;
    v->moreValues[4] = x * z;
    v->moreValues[5] = y * z;
    v->moreValues[6] = x;
    v->moreValues[7] = y;
    v->moreValues[8] = z;
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
    double moreValues[10];
} Matrix4SymType;

VALUE Matrix4Sym_class_method_zero(VALUE clazz) {
    VALUE idNew = rb_intern("new");
    VALUE obj = rb_funcall(clazz, idNew, 0);

    Matrix4SymType *v = malloc(sizeof(Matrix4SymType));
    for (int i = 0; i < TMatrix4SymType_KPS_COUNT; ++i)
        v->kps[i] = 0;
    for (int i = 0; i < 10; ++i)
        v->moreValues[i] = 0;
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

    v->moreValues[0] = a * a;
    v->moreValues[1] = b * b;
    v->moreValues[2] = c * c;
    v->moreValues[3] = a * b;
    v->moreValues[4] = a * c;
    v->moreValues[5] = b * c;
    v->moreValues[6] = a;
    v->moreValues[7] = b;
    v->moreValues[8] = c;
    v->moreValues[9] = d * d;

    VALUE matDataObject = Data_Wrap_Struct(rb_cObject, 0, free, v);
    VALUE idMatDataObj = rb_intern("mat_data_obj");
    rb_ivar_set(obj, idMatDataObj, matDataObject);
    return obj;
}

VALUE Matrix4Sym_class_method_from_face(VALUE clazz, VALUE v1, VALUE v2, VALUE v3) {
    VALUE idNew = rb_intern("new");
    VALUE idVec3DataObj = rb_intern("vec3_data_obj");
    VALUE rbVec3DataObj;

    VALUE obj = rb_funcall(clazz, idNew, 0);

    Vec3Type *vec1, *vec2, *vec3;
    rbVec3DataObj = rb_ivar_get(v1, idVec3DataObj);
    Data_Get_Struct(rbVec3DataObj, Vec3Type, vec1);
    rbVec3DataObj = rb_ivar_get(v2, idVec3DataObj);
    Data_Get_Struct(rbVec3DataObj, Vec3Type, vec2);
    rbVec3DataObj = rb_ivar_get(v3, idVec3DataObj);
    Data_Get_Struct(rbVec3DataObj, Vec3Type, vec3);

    // calculate normal vector
    double x1 = vec1->values[0] - vec2->values[0];
    double y1 = vec1->values[1] - vec2->values[1];
    double z1 = vec1->values[2] - vec2->values[2];
    double x2 = vec1->values[0] - vec3->values[0];
    double y2 = vec1->values[1] - vec3->values[1];
    double z2 = vec1->values[2] - vec3->values[2];

    // y1*z2 - y2*z1
    double a = y1 * z2 - y2 * z1;
    double b = z1 * x2 - z2 * x1;
    double c = x1 * y2 - x2 * y1;
    double r = sqrt(a*a+b*b+c*c);
    if (r == 0) {
        rb_raise(rb_eRuntimeError, "these three vectors cannot make a face");
        return Qnil;
    }

    a /= r;
    b /= r;
    c /= r;
    double d = 1;

    Matrix4SymType *v = malloc(sizeof(Matrix4SymType));

    v->kps[0] =  a * a; v->kps[1] =  b * a; v->kps[2] =  c * a; v->kps[3] =  d * a;
    v->kps[4] =  a * b; v->kps[5] =  b * b; v->kps[6] =  c * b; v->kps[7] =  d * b;
    v->kps[8] =  a * c; v->kps[9] =  b * c; v->kps[10] = c * c; v->kps[11] = d * c;
    v->kps[12] = a * d; v->kps[13] = b * d; v->kps[14] = c * d; v->kps[15] = d * d;

    v->moreValues[0] = a * a;
    v->moreValues[1] = b * b;
    v->moreValues[2] = c * c;
    v->moreValues[3] = a * b;
    v->moreValues[4] = a * c;
    v->moreValues[5] = b * c;
    v->moreValues[6] = a;
    v->moreValues[7] = b;
    v->moreValues[8] = c;
    v->moreValues[9] = d * d;

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

VALUE Matrix4Sym_method_add_bang(VALUE self, VALUE other) {
    VALUE idMatDataObj = rb_intern("mat_data_obj");
    VALUE rbMatObject;
    Matrix4SymType *matObj1, *matObj2;

    rbMatObject = rb_ivar_get(self, idMatDataObj);
    Data_Get_Struct(rbMatObject, Matrix4SymType, matObj1);
    rbMatObject = rb_ivar_get(other, idMatDataObj);
    Data_Get_Struct(rbMatObject, Matrix4SymType, matObj2);

    for (int i = 0; i < TMatrix4SymType_KPS_COUNT; ++i) {
        matObj1->kps[i] += matObj2->kps[i];
    }
    for (int i = 0; i < 10; ++i) {
        matObj1->moreValues[i] += matObj2->moreValues[i];
     }

    return Qnil;
}

VALUE Matrix4Sym_method_delta(VALUE self, VALUE vec) {
    VALUE idVec3DataObj = rb_intern("vec3_data_obj");
    Vec3Type *vec3DataObj;
    VALUE rbVec3DataObj = rb_ivar_get(vec, idVec3DataObj);
    Data_Get_Struct(rbVec3DataObj, Vec3Type, vec3DataObj);

    VALUE idMatDataObj = rb_intern("mat_data_obj");
    VALUE rbMatObject = rb_ivar_get(self, idMatDataObj);
    Matrix4SymType *matObj;
    Data_Get_Struct(rbMatObject, Matrix4SymType, matObj);

//    double *xi = vec3DataObj->values;
    double *xiMore = vec3DataObj->moreValues;
//    double *kij = matObj->kps;
    double *kijMore = matObj->moreValues;

    double ret = 0;
    ret += xiMore[0] * kijMore[0]; // 0,0
    ret += xiMore[1] * kijMore[1]; // 1,1
    ret += xiMore[2] * kijMore[2]; // 2,2
    ret += kijMore[9];             // 3,3

    double rest = 0;
    rest += xiMore[3] * kijMore[3]; // xiMore 0,1
    rest += xiMore[4] * kijMore[4]; // xiMore 0,2
    rest += xiMore[5] * kijMore[5]; // xiMore 1,2
    rest += xiMore[6] * kijMore[6]; // x
    rest += xiMore[7] * kijMore[7]; // y
    rest += xiMore[8] * kijMore[8]; // z

    ret += rest * 2;
    return rb_float_new(ret);
}