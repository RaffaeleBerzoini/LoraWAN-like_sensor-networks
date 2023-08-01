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

  int sockfd;
  int connection;
  int sent;
  struct sockaddr_in servaddr;
  
  bool locked;
  
  bool actual_send (uint16_t address, message_t* packet);

  
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
			msg -> value = call Random.rand16() % 50;
			msg -> type = 0;
			msg -> sender = TOS_NODE_ID;
			msg -> id = 1;
	  	actual_send(AM_BROADCAST_ADDR, &packet);
		}
		return;
  }


  
  bool actual_send (uint16_t address, message_t* packet){

		node_msg_t* msg = (node_msg_t*)call Packet.getPayload(packet, sizeof(node_msg_t)); // payload retrieval
	
		if (call AMSend.send(address, packet, sizeof(node_msg_t)) == SUCCESS){
			switch(msg->type){
				case DATA:
					dbg("radio_send", "sent DATA message at %s with:\n\t\tsender: %d\n\t\tid: %d\n\t\tvalue: %d\n", sim_time_string(), msg->sender, msg->id, msg->value);
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
				call Timer.startOneShot(5000);
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

			if (TOS_NODE_ID == 6 || TOS_NODE_ID == 7)
			{
					// Logic based on the type of message and status of the routing_table variable
					switch(msg->type){
						case DATA:
							dbg("radio_rec", "received DATA message at %s with:\n\t\tsender: %d\n\t\tid: %d\n\t\tvalue: %d\n", sim_time_string(), msg->sender, msg->id, msg->value);
							msg_packet -> value = msg->value;
							msg_packet -> type = msg->type;
							msg_packet -> sender = msg->sender;
							msg_packet -> id = msg->id;
					  	actual_send(SERVER, &packet);					
							break;
					}
			}
			else if (TOS_NODE_ID == SERVER)
			{
				dbg("radio_rec", "received DATA message at %s with:\n\t\tsender: %d\n\t\tid: %d\n\t\tvalue: %d\n", sim_time_string(), msg->sender, msg->id, msg->value);
				msg_packet -> value = msg->value;
				msg_packet -> type = msg->type;
				msg_packet -> sender = msg->sender;
				msg_packet -> id = msg->id;
				//handle id and send ack
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
				sleep(16); // Emulate the periodic sending of messages
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




