#include "Timer.h"
#include "Nodes.h"

#define N_NODES 8
#define SERVER 8

module NodesC @safe() {
  uses {
  
    /****** INTERFACES *****/
	interface Boot;
	interface Timer<TMilli> as Timer;
	//interfaces for communication
	interface Receive;
	interface AMSend;
	//other interfaces, if needed
	interface SplitControl as AMControl;
	interface Packet;
	interface Random;
  }
}
implementation {

  message_t packet;
  
  // Variables to store the message to send
  message_t queued_packet;
  uint16_t queue_addr;
  uint16_t time_delays[7]={61,173,267,371,479,583,689}; //Time delay in milli seconds
  
  
  bool route_req_sent=FALSE;
  bool route_rep_sent=FALSE;
  
  
  bool locked;
  
  bool actual_send (uint16_t address, message_t* packet);
  bool generate_send (uint16_t address, message_t* packet, uint8_t type);
  
  
  
  
  
  
  bool generate_send (uint16_t address, message_t* packet, uint8_t type){

  	if (call Timer.isRunning()){
  		return FALSE;
  	}else{
  	if (type == 1 && !route_req_sent ){
  		route_req_sent = TRUE;
  		call Timer.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 2 && !route_rep_sent){
  	  	route_rep_sent = TRUE;
  		call Timer.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 0){
  		call Timer.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;	
  	}
  	}
  	return TRUE;
  }


  
  event void Timer.fired() {

		dbg("timer", "timer fired at time %s \n", sim_time_string());

		if (locked){
			return;
		}
		else{
			node_msg_t* msg = (node_msg_t*)call Packet.getPayload(&packet, sizeof(node_msg_t));
			if (msg == NULL){
				dbgerror("radio_send", "unable to allocate message memory\n");
				return;
			}
			msg -> value = call Random.rand16();
			msg -> type = 0;
			msg -> sender = TOS_NODE_ID;
			msg -> id = 1;
	  	actual_send (AM_BROADCAST_ADDR, &packet);
		}

  }


  
  bool actual_send (uint16_t address, message_t* packet){

	node_msg_t* msg = (node_msg_t*)call Packet.getPayload(packet, sizeof(node_msg_t)); // payload retrieval
	
		if (call AMSend.send(address, packet, sizeof(node_msg_t)) == SUCCESS){
			switch(msg->type){
				case DATA:
					dbg("radio_send", "sent DATA message at %s with:\n\t\tsender: %d\n\t\tid: %d\n\t\tvalue: %d\n\t\taddress: %d\n", sim_time_string(), msg->sender, msg->id, msg->value, address);
					break;
  		}
  	}
  }
  

  
  event void Boot.booted() {

    dbg("boot","Node %d Application booted.\n", TOS_NODE_ID);            
    call AMControl.start();
  }



  event void AMControl.startDone(error_t err) {

		if (err == SUCCESS) {
			dbg("radio", "Radio on node %d!\n", TOS_NODE_ID);
			if (TOS_NODE_ID <= 5)
			{
				call Timer.startPeriodic(5000);
			}
		}
		else{
			dbgerror("radio", "Radio failed to start, retrying.\n");
		  call AMControl.start();
		}
  }



  event void AMControl.stopDone(error_t err) {
  }
  


  event message_t* Receive.receive(message_t* bufPtr, 
				   void* payload, uint8_t len) {

	if (len != sizeof(node_msg_t)){return bufPtr;}
	else{
		node_msg_t* msg = (node_msg_t*)payload; //received payload
		node_msg_t* msg_packet = (node_msg_t*)call Packet.getPayload(&packet, sizeof(node_msg_t)); // new message payload to be possibly sent
		dbg("radio_rec", "Node %d is inside receive event\n", TOS_NODE_ID);		
		if (TOS_NODE_ID == 6 || TOS_NODE_ID == 7)
		{
				// Logic based on the type of message and status of the routing_table variable
				switch(msg->type){
					case DATA:
						dbg("radio_rec", "received DATA message at %s with:\n\t\tsender: %d\n\t\t\id: %d\n\t\tvalue: %d\n", sim_time_string(), msg->sender, msg->id, msg->value);
						msg_packet->type = msg->type;
						msg_packet->sender = msg->sender;
						msg_packet->id = msg->id;
						msg_packet->value = msg->value;						
						actual_send(SERVER, &packet);
						break;
				}
		}
	  else if (TOS_NODE_ID == SERVER)
	  {
		  dbg("radio_rec", "server received");
			dbg("radio_rec", "received DATA message at %s with:\n\t\tsender: %d\n\t\t\id: %d\n\t\tvalue: %d\n", sim_time_string(), msg->sender, msg->id, msg->value);
		 //handle id and send ack
  	}
  }
  }



  event void AMSend.sendDone(message_t* bufPtr, error_t error) {

		if (&packet == bufPtr || &queued_packet == bufPtr){
			locked = FALSE;
		}else{
			dbg("radio_send", "message not sent\n");		
		}
  }
}




