#ifndef NODE_H
#define NODE_H
#define MESSAGE_BUFFER 5

typedef nx_struct node_msg {
	nx_int8_t type;
	nx_uint8_t id;
	nx_uint8_t value;
	nx_int8_t sender;
	nx_uint8_t delimiter1;
	nx_int8_t delimiter2;
} node_msg_t;

enum {
  AM_RADIO_COUNT_MSG = 10,
};

enum{
	DATA = 0,
	ACK = 1
};

#endif
