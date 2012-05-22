#ifndef pipe_h
#define pipe_h
#include <stdlib.h>//for size_t
template<class T> class Pipe { // SINGLE writer, SINGLE reader queue
 private:
  volatile size_t _head;
  volatile size_t _tail;
  size_t _capacity;
  T* _pool;//Have to alloc
  bool _overwrite;

 public:
 Pipe(size_t size, bool overwrite=false)
   : _tail(0), _head(0), _capacity(size+1), _overwrite(overwrite)
    , _pool((T*)malloc(sizeof(T) * _capacity)) {
  };
  virtual ~Pipe() {
    if(_pool) free(_pool);
  };
  inline size_t len() const {
    size_t h = _head, t = _tail;
    return (h >= t) 
      ? h - t
      : h + _capacity - t;
  };
  inline bool isEmpty() const { return _head == _tail; };
  inline bool isFull() const { return ((_head+1) % _capacity) == _tail; };
  inline bool push(T& node) {
    if(isFull() && !_overwrite) return false;
    _pool[_head] = node; // just a shallow copy for now
    _head = (_head+1) % _capacity;
    return true;
  };
  inline bool pop(T& node) {
    if(isEmpty()) return false;
    node = _pool[_tail]; // just a shallow copy for now
    _tail = (_tail+1) % _capacity;
    return true;
  };
  inline bool pop() {
    if(isEmpty()) return false;
    _tail = (_tail+1) % _capacity;
    return true;
  };

  inline T& operator[](size_t i) const { return _pool[(_tail+i) % _capacity]; }
};
#endif//pipe_h
