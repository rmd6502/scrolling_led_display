import processing.serial.*;

Serial serialPort;
Twitter myTwitter;

static final int DELAYSECS = 15;
static final int NUMRESPONSES = 1;

void setup() {
  
  serialPort = new Serial(this, Serial.list()[1], 115200);
  serialPort.clear();
  
  myTwitter = new Twitter(); // anon access
  
  HashMap tweetQueue = new HashMap(); // store a queue of tweets
  
};

void draw() {
  
  while (true) {
      try {

        Query query = new Query("alphaonelabs");
        query.setRpp(NUMRESPONSES);
        QueryResult result = myTwitter.search(query);
    
        ArrayList tweets = (ArrayList) result.getTweets();
    
        for (int i = 0; i < tweets.size(); i++) {
                    
          Tweet t = (Tweet) tweets.get(i);
          String user = t.getFromUser();
          String msg = t.getText();
          Date d = t.getCreatedAt();
          println("Tweet by " + user + " at " + d + ": " + msg);

          String scrollMsg = user + ": " + msg + "\n";
          serialInit();
          scroll(scrollMsg); 
        };
    
      }
      catch (TwitterException te) {
        println("Couldn't connect: " + te);
      };
      
      delay(DELAYSECS * 1000); // 15 secs between queries
  }

};


void serialInit() {
  
  delay(50);
  serialPort.clear();
  delay(50);
  serialPort.write("\nc\n");
  delay(50);
}


void scroll(String s) {
  
  int slen = s.length();
  println("slen: " + slen);
  String[] schars = s.split("");
  int pos = 96;
  
  String wholestring = "";
  
  for (int i=0; i < schars.length; i++)
  {
    print("i: " + i + " ");
    
    String currChar = schars[i];
    byte[] charBytes = currChar.getBytes();
    if (charBytes.length==1) {

      byte currByte = charBytes[0]; // we only care about the first byte
    
//    println("char" + i + ": " + schars[i]);
      if ((currByte >= 32) && (currByte <= 127)) {
       
        wholestring += (char)currByte;

        println("ws: " + wholestring);
        
        serialPort.write("p" + pos + "\n");    delay(10);
        serialPort.write("s" + wholestring + "\n ");   delay(400);    
        
        if (pos >= 6)
        {
          for (int j=0; (j < 6); j++) {
            serialPort.write("l1");
            delay(25);
          }
          pos -= 6;
        }
        else
        {
          // we need to remove the first char
          wholestring = wholestring.substring(1);
        }
          
        
      } // end ascii test
      
    } // end if charbytes
  }  
  
  delay(250);
  for (int i=0; i < 96; i++) {
    delay(50);
    serialPort.write("l1");
  }

}
