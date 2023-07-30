#ifndef NODE_H
#define NODE_H

typedef nx_struct node_msg {
	nx_int8_t type;
	nx_int8_t sender;
	nx_uint8_t id;
	nx_uint16_t value;
} node_msg_t;

enum {
  AM_RADIO_COUNT_MSG = 10,
};

enum{
	DATA = 0,
	ACK = 1
};

#endif
