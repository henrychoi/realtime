#ifndef rts_ring_h
#define rts_ring_h

template<typename T> class Ring {
protected:
  T* _array;
  size_t capacity;
public:
  ~Ring() { if(_array) free(_array); };
  Ring(size_t capacity) { _array = (T*)malloc(sizeof(T) * capacity); };
  T& operator[](size_t idx) { return _array[idx % capacity]; };
};

#endif//rts_ring_h