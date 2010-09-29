import processing.serial.*;

Serial serialPort;
Twitter myTwitter;

static final int DELAYSECS = 0;
static final int NUMRESPONSES = 1;
static final int SMALLDELAY = 40;

String lastTweet = ""; // for comparison
String latestTweet = "";


void setup() {
  
  serialPort = new Serial(this, Serial.list()[1], 115200);
  myTwitter = new Twitter(); // anon access  
  
};


void draw() {

  try {
      Query query = new Query("alphaonelabs");
      query.setRpp(NUMRESPONSES);
      QueryResult result = myTwitter.search(query);
  
      ArrayList tweets = (ArrayList) result.getTweets();
  
      for (int i = 0; i < tweets.size(); i++) 
      {                   
        Tweet t = (Tweet) tweets.get(i);
        String user = t.getFromUser();
        latestTweet = t.getText();
        Date d = t.getCreatedAt();
        println("Tweet by " + user + " at " + d + ": " + latestTweet);

        serialInit(); // clear the screen
        
        println("lastTweet: " + lastTweet + " latestTweet: " + latestTweet + "\n");
        if (! latestTweet.equals(lastTweet))
        {
          scroll("<<<<<<<<<<<<<<<<\n", false); // indicate a new tweet
        }
        
        String scrollMsg = user + ": " + latestTweet + "\n";   
        scroll(scrollMsg, true);
        
        lastTweet = latestTweet; // keep track
      };
  
    }
    catch (TwitterException te) {
      println("Couldn't connect: " + te);
    };
    
    delay(DELAYSECS * 1000); // secs between queries

};


void serialInit() {
  
  delay(50);
  serialPort.clear();
  delay(50);
  serialPort.write("\nc\n");
  delay(50);
}


void scroll(String s, Boolean flushLeft) {
  
  int slen = s.length();
  println("slen: " + slen);
  String[] schars = s.split("");
  int pos = 463+100;
  
  String cleanString = "";
  
  for (int i=0; i < schars.length; i++)
  {
    //print("i: " + i + " ");
    
    String currChar = schars[i];
    byte[] charBytes = currChar.getBytes();
    if ((charBytes.length==1) && (charBytes[0] >= 32) && (charBytes[0] <= 127)) 
    {   
        cleanString += (char)charBytes[0];
    } // ignore any unicode or non ascii char
  }  

  //println("ws: " + wholestring);
  
  serialPort.write("p" + pos + "\n");
  delay(SMALLDELAY);
  serialPort.write("s" + cleanString + "\n"); 
  delay(SMALLDELAY);
  
  //delay(cleanString.length()/2 );
 
  int messageLen = 6*cleanString.length() + 6; // add 1 char and 1 entire screen width

  if (flushLeft)
    messageLen += 100; // flush the screen all the way left if desired
  
  for (int i=0; i < messageLen; i++) 
  { // move the chars left one vertical column at a time
    serialPort.write("l1");
    delay(SMALLDELAY);
  }

}
