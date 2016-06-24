#include "ruby.h"
#include <math.h>
#include <immintrin.h>

VALUE Fast4DMatrix = Qnil;
VALUE Vec3 = Qnil;
VALUE Matrix4Sym = Qnil;

// method declarations
void Init_fast_4d_matrix();
VALUE Vec3_singleton_method_from_a(VALUE self, VALUE rbx, VALUE rby, VALUE rbz);
VALUE Vec3_method_to_a(VALUE self);
VALUE Vec3_method_line_question(VALUE self, VALUE v2, VALUE v3);
VALUE Vec3_method_mid(VALUE self, VALUE other);

VALUE Matrix4Sym_class_method_zero(VALUE clazz);
VALUE Matrix4Sym_class_method_from_vec4(VALUE clazz, VALUE a, VALUE b, VALUE c, VALUE d);
VALUE Matrix4Sym_class_method_from_face(VALUE clazz, VALUE v1, VALUE v2, VALUE v3);
VALUE Matrix4Sym_method_to_a(VALUE self);
VALUE Matrix4Sym_method_delta(VALUE self, VALUE vec);
VALUE Matrix4Sym_method_add_bang(VALUE self, VALUE other);
VALUE Matrix4Sym_method_get_best_vertex(VALUE self);

void Init_fast_4d_matrix() {
  Fast4DMatrix = rb_define_module("Fast4DMatrix");

  Vec3 = rb_define_class_under(Fast4DMatrix, "Vec3", rb_cObject);
  rb_define_singleton_method(Vec3, "from_a", Vec3_singleton_method_from_a, 3);
  rb_define_method(Vec3, "to_a", Vec3_method_to_a, 0);
  rb_define_method(Vec3, "line?", Vec3_method_line_question, 2);
  rb_define_method(Vec3, "mid", Vec3_method_mid, 1);

  Matrix4Sym = rb_define_class_under(Fast4DMatrix, "Matrix4Sym", rb_cObject);
  rb_define_singleton_method(Matrix4Sym, "zero", Matrix4Sym_class_method_zero, 0);
  rb_define_singleton_method(Matrix4Sym, "from_vec4", Matrix4Sym_class_method_from_vec4, 4);
  rb_define_singleton_method(Matrix4Sym, "from_face", Matrix4Sym_class_method_from_face, 3);
  rb_define_method(Matrix4Sym, "to_a", Matrix4Sym_method_to_a, 0);
  rb_define_method(Matrix4Sym, "delta", Matrix4Sym_method_delta, 1);
  rb_define_method(Matrix4Sym, "add!", Matrix4Sym_method_add_bang, 1);
  rb_define_method(Matrix4Sym, "get_best_vertex", Matrix4Sym_method_get_best_vertex, 0);
}

typedef struct TVec3Type {
  double values[3];
  double moreValues[9];

  __m128 m1;
  __m256 m2;
} Vec3Type;

VALUE Vec3_singleton_method_from_a(VALUE clazz, VALUE rbx, VALUE rby, VALUE rbz) {
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

  v->m2[0] = x * x;
  v->m2[1] = y * y;
  v->m2[2] = z * z;
  v->m2[3] = x * y;
  v->m2[4] = x * z;
  v->m2[5] = y * z;
  v->m2[6] = v->m2[7] = 0;

  v->m1[0] = x;
  v->m1[1] = y;
  v->m1[2] = z;
  v->m1[3] = 1;

  VALUE ret = Data_Wrap_Struct(Vec3, 0, free, v);
  return ret;
}

VALUE Vec3_method_to_a(VALUE self) {
  Vec3Type *v;
  Data_Get_Struct(self, Vec3Type, v);

  VALUE ret = rb_ary_new();
  rb_ary_push(ret, rb_float_new(v->values[0]));
  rb_ary_push(ret, rb_float_new(v->values[1]));
  rb_ary_push(ret, rb_float_new(v->values[2]));

  return ret;
}

VALUE Vec3_method_mid(VALUE self, VALUE other) {
  Vec3Type *v1;
  Data_Get_Struct(self, Vec3Type, v1);
  Vec3Type *v2;
  Data_Get_Struct(other, Vec3Type, v2);
  
  double x = (v1->values[0] + v2->values[0]) / 2; 
  double y = (v1->values[1] + v2->values[1]) / 2; 
  double z = (v1->values[2] + v2->values[2]) / 2; 

  return rb_funcall(Vec3, rb_intern("from_a"), 3, 
      rb_float_new(x), 
      rb_float_new(y), 
      rb_float_new(z));
}
#define TMatrix4SymType_KPS_COUNT 16
typedef struct TMatrix4SymType {
  double kps[TMatrix4SymType_KPS_COUNT];
  double moreValues[10];
} Matrix4SymType;

VALUE Matrix4Sym_class_method_zero(VALUE clazz) {
  Matrix4SymType *v = malloc(sizeof(Matrix4SymType));
  for (int i = 0; i < TMatrix4SymType_KPS_COUNT; ++i)
    v->kps[i] = 0;
  for (int i = 0; i < 10; ++i)
    v->moreValues[i] = 0;
  return Data_Wrap_Struct(clazz, 0, free, v);
}

VALUE Matrix4Sym_class_method_from_vec4(VALUE clazz, VALUE aa, VALUE bb, VALUE cc, VALUE dd) {
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

  return Data_Wrap_Struct(clazz, 0, free, v);
}

VALUE Matrix4Sym_class_method_from_face(VALUE clazz, VALUE v1, VALUE v2, VALUE v3) {
  Vec3Type *vec1, *vec2, *vec3;
  Data_Get_Struct(v1, Vec3Type, vec1);
  Data_Get_Struct(v2, Vec3Type, vec2);
  Data_Get_Struct(v3, Vec3Type, vec3);

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
  double d = 0;
  double r = sqrt(a*a+b*b+c*c);
  //    if (r == 0) {
  //        rb_raise(rb_eRuntimeError, "these three vectors cannot make a face");
  //        return Qnil;
  //    }

  if (r == 0) {
    a = b = c = 1;
    d = 0;
  }
  else {
    a /= r;
    b /= r;
    c /= r;
    d = -(a * vec1->values[0] + b * vec1->values[1] + c * vec1->values[2]);
  }

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
  v->moreValues[6] = a * d;
  v->moreValues[7] = b * d;
  v->moreValues[8] = c * d;
  v->moreValues[9] = d * d;

  return Data_Wrap_Struct(clazz, 0, free, v);
}

VALUE Matrix4Sym_method_to_a(VALUE self) {
  Matrix4SymType *v;
  Data_Get_Struct(self, Matrix4SymType, v);

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
  Matrix4SymType *matObj1, *matObj2;
  Data_Get_Struct(self, Matrix4SymType, matObj1);
  Data_Get_Struct(other, Matrix4SymType, matObj2);

  for (int i = 0; i < TMatrix4SymType_KPS_COUNT; ++i) {
    matObj1->kps[i] += matObj2->kps[i];
  }
  for (int i = 0; i < 10; ++i) {
    matObj1->moreValues[i] += matObj2->moreValues[i];
  }
  return Qnil;
}

VALUE Matrix4Sym_method_delta(VALUE self, VALUE vec) {
  Vec3Type *vec3DataObj;
  Data_Get_Struct(vec, Vec3Type, vec3DataObj);
  Matrix4SymType *matObj;
  Data_Get_Struct(self, Matrix4SymType, matObj);

  double ret = 0;

  //    double *xi = vec3DataObj->values;
  //    double *kij = matObj->kps;

  double *xiMore = vec3DataObj->moreValues;
  double *kijMore = matObj->moreValues;

  //    ret += xiMore[0] * kijMore[0]; // 0,0
  //    ret += xiMore[1] * kijMore[1]; // 1,1
  //    ret += xiMore[2] * kijMore[2]; // 2,2
  //    ret += kijMore[9];             // 3,3

  double rest = 0;
  //    rest += xiMore[3] * kijMore[3]; // xiMore 0,1
  //    rest += xiMore[4] * kijMore[4]; // xiMore 0,2
  //    rest += xiMore[5] * kijMore[5]; // xiMore 1,2
  //    rest += xiMore[6] * kijMore[6]; // xiMore 0,3
  //    rest += xiMore[7] * kijMore[7]; // xiMore 1,3
  //    rest += xiMore[8] * kijMore[8]; // xiMore 2,3

  float aLineFloat1[4];
  float bLineFloat1[4];
  for (int i = 0; i < 3; ++i) {
    aLineFloat1[i] = xiMore[i];
    bLineFloat1[i] = kijMore[i];
  }
  aLineFloat1[3] = 1;
  bLineFloat1[3] = kijMore[9];

  __m128 *m128A = (__m128*) aLineFloat1;
  __m128 *m128B = (__m128*) bLineFloat1;
  __m128 retM128 = _mm_mul_ps(*m128A, *m128B);
  for (int i = 0; i < 4; ++i) {
    ret += retM128[i];
  }

  float aLineFloat[8] = { 0 };
  float bLineFloat[8] = { 0 };
  for (int i = 0; i < 6; ++i) {
    aLineFloat[i] = xiMore[3 + i];
    bLineFloat[i] = kijMore[3 + i];
  }
  __m256 ymm0 = _mm256_loadu_ps(aLineFloat);
  __m256 ymm1 = _mm256_loadu_ps(bLineFloat);
  __m256 restM256 = _mm256_mul_ps(ymm0, ymm1);
  for (int i = 0; i < 6; ++i) {
    rest += restM256[i];
  }

  ret += rest * 2;
  return rb_float_new(ret);
}

VALUE Vec3_method_line_question(VALUE self, VALUE v2, VALUE v3) {
  Vec3Type *vec3DataObj1, *vec3DataObj2, *vec3DataObj3;
  Data_Get_Struct(self, Vec3Type, vec3DataObj1);
  Data_Get_Struct(v2, Vec3Type, vec3DataObj2);
  Data_Get_Struct(v3, Vec3Type, vec3DataObj3);

  double dx1 = vec3DataObj1->values[0] - vec3DataObj2->values[0]; 
  double dy1 = vec3DataObj1->values[1] - vec3DataObj2->values[1];
  double dz1 = vec3DataObj1->values[2] - vec3DataObj2->values[2];

  double dx2 = vec3DataObj1->values[0] - vec3DataObj3->values[0];
  double dy2 = vec3DataObj1->values[1] - vec3DataObj3->values[1];
  double dz2 = vec3DataObj1->values[2] - vec3DataObj3->values[2];

  int result = 
    (dy1 * dz2 - dz1 * dy2 == 0) &&
    (dz1 * dx2 - dx1 * dz2 == 0) &&
    (dx1 * dy1 - dy1 * dx2 == 0);

  return result ? Qtrue : Qfalse;
}

VALUE Matrix4Sym_method_get_best_vertex(VALUE self) {
  Matrix4SymType *matObj;
  Data_Get_Struct(self, Matrix4SymType, matObj);

  double d = 
    matObj->kps[0] * matObj->kps[5] * matObj->kps[10] 
    + matObj->kps[1] * matObj->kps[6] * matObj->kps[8]
    + matObj->kps[4] * matObj->kps[9] * matObj->kps[2]
    - matObj->kps[2] * matObj->kps[5] * matObj->kps[8]
    - matObj->kps[1] * matObj->kps[4] * matObj->kps[10]
    - matObj->kps[6] * matObj->kps[9] * matObj->kps[0];

  //for (int i = 0; i < 16; ++i) {
  //  fprintf(stderr, "%f, ", matObj->kps[i]);
  //}
  //fprintf(stderr, "\n");

  if (d == 0)
    return Qnil;

  double d0 = 
    matObj->kps[3] * matObj->kps[5] * matObj->kps[10] 
    + matObj->kps[1] * matObj->kps[6] * matObj->kps[11]
    + matObj->kps[7] * matObj->kps[9] * matObj->kps[2]
    - matObj->kps[2] * matObj->kps[5] * matObj->kps[11]
    - matObj->kps[1] * matObj->kps[7] * matObj->kps[10]
    - matObj->kps[6] * matObj->kps[9] * matObj->kps[3];

  double d1 = 
    matObj->kps[0] * matObj->kps[7] * matObj->kps[10] 
    + matObj->kps[3] * matObj->kps[6] * matObj->kps[8]
    + matObj->kps[4] * matObj->kps[11] * matObj->kps[2]
    - matObj->kps[2] * matObj->kps[7] * matObj->kps[8]
    - matObj->kps[3] * matObj->kps[4] * matObj->kps[10]
    - matObj->kps[6] * matObj->kps[11] * matObj->kps[0];
  
  double d2 = 
    matObj->kps[0] * matObj->kps[5] * matObj->kps[11] 
    + matObj->kps[1] * matObj->kps[7] * matObj->kps[8]
    + matObj->kps[4] * matObj->kps[9] * matObj->kps[3]
    - matObj->kps[3] * matObj->kps[5] * matObj->kps[8]
    - matObj->kps[1] * matObj->kps[4] * matObj->kps[11]
    - matObj->kps[7] * matObj->kps[9] * matObj->kps[0];

  return rb_funcall(Vec3, rb_intern("from_a"), 3, 
      rb_float_new(- d0 / d),
      rb_float_new(- d1 / d),
      rb_float_new(- d2 / d)); 
}
