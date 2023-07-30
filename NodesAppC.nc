
 
#include "Nodes.h"


configuration NodesAppC {}
implementation {
/****** COMPONENTS *****/
  components MainC, NodesC as App;
  //add the other components here
  
  
  
  /****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;
  
  /****** Wire the other interfaces down here *****/

}


