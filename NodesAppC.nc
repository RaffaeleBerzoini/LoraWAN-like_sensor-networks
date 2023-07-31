
 
#include "Nodes.h"


configuration NodesAppC {}
implementation {
/****** COMPONENTS *****/
  //add the other components here
  components MainC, NodesC as App;
  
  components new AMSenderC(AM_RADIO_COUNT_MSG);
  components new AMReceiverC(AM_RADIO_COUNT_MSG);
  components new TimerMilliC() as Timer;
  components ActiveMessageC;
  components RandomC;
  
  /****** INTERFACES *****/
  App.Boot -> MainC.Boot;
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  App.AMControl -> ActiveMessageC;
  App.Timer -> Timer;
  App.Packet -> AMSenderC;
  App.Random -> RandomC;

}


