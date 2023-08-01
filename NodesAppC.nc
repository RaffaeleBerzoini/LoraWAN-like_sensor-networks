
 
#include "Nodes.h"


configuration NodesAppC {}
implementation {
/****** COMPONENTS *****/
  //add the other components here
  components MainC, NodesC as App;
  
  components new AMSenderC(AM_RADIO_COUNT_MSG);
  components new AMReceiverC(AM_RADIO_COUNT_MSG);
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components ActiveMessageC;
  components RandomC;
  
  /****** INTERFACES *****/
  App.Boot -> MainC.Boot;
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  App.AMControl -> ActiveMessageC;
  App.Timer0 -> Timer0;
  App.Timer1 -> Timer1;
  App.Packet -> AMSenderC;
  App.Random -> RandomC;

}


