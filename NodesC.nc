#include "Timer.h"
#include "Nodes.h"
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>


#define N_NODES 8
#define SERVER 8
#define SERVER_IP "127.0.0.1"
#define SERVER_PORT 1234
#define MAX_PUB 1


module NodesC @safe() {
  uses {
  
    /****** INTERFACES *****/
	interface Boot;
	interface Timer<TMilli> as Timer0;
	interface Timer<TMilli> as Timer1;
	interface Timer<TMilli> as Timer2;
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
  node_msg_t last_msg_sent;
  
  uint16_t time_delays[2]={61,173};
  uint16_t last_MID_received[5] = {0, 0, 0, 0, 0};
  uint16_t start_timer[5] = {1000, 1200, 1400, 1600, 1800};
  int current_msg_id = 1;

  int sockfd;
  int connection;
  int sent;
  struct sockaddr_in servaddr;
  
  bool locked;
  bool ack_received = TRUE; //set to true at beginning just for firts message logic
  
  bool actual_send (uint16_t address, message_t* packet);

  
  event void Timer0.fired() {

		dbg("timer", "timer fired at time %s \n", sim_time_string());

		if (locked){
			return;
		}
		else{
			if(ack_received){
				node_msg_t* msg = (node_msg_t*)call Packet.getPayload(&packet, sizeof(node_msg_t));
				if (msg == NULL){
					dbgerror("radio_send", "unable to allocate message memory\n");
					return;
				}
				msg -> value = call Random.rand16() % 50;
				msg -> type = DATA;
				msg -> sender = TOS_NODE_ID;
				msg -> id = current_msg_id;
				current_msg_id++;
			
				actual_send(AM_BROADCAST_ADDR, &packet);
				ack_received = FALSE;
				call Timer2.startOneShot(1000);
				
				last_msg_sent.value = msg -> value;
				last_msg_sent.type = msg -> type;
				last_msg_sent.sender = msg -> sender;
				last_msg_sent.id = msg -> id;
	  	}
		}
		return;
  }
  
  event void Timer2.fired() {
  	if(!ack_received){
			node_msg_t* msg = (node_msg_t*)call Packet.getPayload(&packet, sizeof(node_msg_t));
			if (msg == NULL){
				dbgerror("radio_send", "unable to allocate message memory\n");
				return;
			}
			msg -> value = last_msg_sent.value;
			msg -> type = last_msg_sent.type;
			msg -> sender = last_msg_sent.sender;
			msg -> id = last_msg_sent.id;
			
			actual_send(AM_BROADCAST_ADDR, &packet);
			
			call Timer2.startOneShot(1000);
			}
		return;
  }
  
  event void Timer1.fired() {
  	actual_send(SERVER, &packet);
  }


  
  bool actual_send (uint16_t address, message_t* packet){

		node_msg_t* msg = (node_msg_t*)call Packet.getPayload(packet, sizeof(node_msg_t)); // payload retrieval
	
		if (call AMSend.send(address, packet, sizeof(node_msg_t)) == SUCCESS){
			switch(msg->type){
				case DATA:
					dbg("radio_send", "sent DATA message at %s with:\n\t\tsender: %d\n\t\tid: %d\n\t\tvalue: %d\n", sim_time_string(), msg->sender, msg->id, msg->value);
					break;
				case ACK:
					dbg("radio_send", "sent ACK message at %s with:\n\t\tsender: %d\n\t\tid: %d\n\t\tvalue: %d\n", sim_time_string(), msg->sender, msg->id, msg->value);
					break;
  		}
		locked = TRUE; // variable to prevent other messages to be sent before the confirmation of the AMSend.sendDone event
		}

		return TRUE;
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
				call Timer0.startPeriodicAt(start_timer[TOS_NODE_ID], 2000);
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
			
			if (TOS_NODE_ID <= 5){
				if(msg->type == ACK && msg->sender == TOS_NODE_ID && msg->id == last_msg_sent.id){
					dbg("radio_rec", "received ACK message at %s with:\n\t\tsender: %d\n\t\tid: %d\n\t\tvalue: %d\n", sim_time_string(), msg->sender, msg->id, msg->value);
					ack_received = TRUE;
				}
			}
			else if (TOS_NODE_ID == 6 || TOS_NODE_ID == 7)
			{
					// Logic based on the type of message and status of the routing_table variable
					switch(msg->type){
						case DATA:
							dbg("radio_rec", "received DATA message at %s with:\n\t\tsender: %d\n\t\tid: %d\n\t\tvalue: %d\n", sim_time_string(), msg->sender, msg->id, msg->value);
							msg_packet -> value = msg->value;
							msg_packet -> type = msg->type;
							msg_packet -> sender = msg->sender;
							msg_packet -> id = msg->id;
					  	call Timer1.startOneShot(time_delays[TOS_NODE_ID - 6]); // for messages received at the same time from both gateways
							break;
						case ACK:
							dbg("radio_rec", "received ACK message at %s with:\n\t\tsender: %d\n\t\tid: %d\n\t\tvalue: %d\n", sim_time_string(), msg->sender, msg->id, msg->value);
							msg_packet -> value = msg->value;
							msg_packet -> type = msg->type;
							msg_packet -> sender = msg->sender;
							msg_packet -> id = msg->id;
							actual_send(AM_BROADCAST_ADDR, &packet);
					}
			}
			else if (TOS_NODE_ID == SERVER)
			{
				if(msg -> type == ACK){return bufPtr;}
				dbg("radio_rec", "received DATA message at %s with:\n\t\tsender: %d\n\t\tid: %d\n\t\tvalue: %d\n", sim_time_string(), msg->sender, msg->id, msg->value);
				// if i have already received the msg from sender msg->sender with id msg->id i ignore it and just send the ack back
				if (msg->id == last_MID_received[msg->sender - 1]) {
					dbg("radio_rec", "Ignoring duplicated message, sending ACK s:  %d, id:  %d, v: %d\n", msg->sender, msg->id, msg->value);
					
					msg_packet -> value = msg->value;
					msg_packet -> type = ACK;
					msg_packet -> sender = msg->sender;
					msg_packet -> id = msg->id;
					actual_send(AM_BROADCAST_ADDR, &packet);
					return bufPtr;
				}
				
				// update the last message received ID and send ACK back
				last_MID_received[msg->sender - 1] = msg->id;
				msg_packet -> value = msg->value;
				msg_packet -> type = ACK;
				msg_packet -> sender = msg->sender;
				msg_packet -> id = msg->id;
				actual_send(AM_BROADCAST_ADDR, &packet);
				
				// send message to nodered
				// Create socket
				sockfd = socket(AF_INET, SOCK_STREAM, 0);
				if(sockfd == -1)
				{
					dbg("error", "Socket creation failed!\n");
					return;
				}
				// Set server address
				servaddr.sin_family = AF_INET;
				servaddr.sin_addr.s_addr = inet_addr(SERVER_IP);
				servaddr.sin_port = htons(SERVER_PORT);
				// Connect to the server
				dbg("radio_send", "connecting socket...\n");
				connection = connect(sockfd, (struct sockaddr*) &servaddr, sizeof(servaddr));
				if(connection != 0)
				{
					dbg("error", "Connection failed! Error: %d\n", connection);
					close(sockfd);
					return;
				}
				// Send the message
				dbg("radio_send", "sending message...\n");
				sent = send(sockfd, msg, sizeof(node_msg_t), 0);
				dbg("error", "Sent bytes: %d\n", sent);
				if(sent == -1)
				{
					dbg("error", "Failed to send message! Error: %d\n", sent);
					return;
				}
				close(sockfd);
			}
		}
		return bufPtr;
  }



  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
		
		if (&packet == bufPtr){
			locked = FALSE;
			//dbg("radio_send", "message sent\n");	
		}else{
			//dbg("radio_send", "message not sent\n");		
		}
  }
}




