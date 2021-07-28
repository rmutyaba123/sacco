/* Basic Java testing class */
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.file.Paths;
import java.nio.file.Files;
import java.util.Base64;
import java.util.Date;
import java.text.SimpleDateFormat;
import java.text.ParseException;

import java.security.MessageDigest;
import java.util.Base64;
import java.nio.charset.StandardCharsets;
import java.security.NoSuchAlgorithmException;

class basic {

	public static void main(String[] args) {

		String myDate = "20200224053844";	
		Date FinalisedTime = new Date();
		//SimpleDateFormat sDateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
		SimpleDateFormat sDateFormat = new SimpleDateFormat("yyyyMMddHHmmss");
		try {
			if(myDate.length() > 12) {
				String fDate = myDate.substring(0,4) + "-" + myDate.substring(4,6) + "-" + myDate.substring(6,8)
					+ " " + myDate.substring(8,10) + ":" + myDate.substring(10,12) + ":" + myDate.substring(12);
				System.out.println(myDate);
				System.out.println(fDate);

				FinalisedTime = sDateFormat.parse(myDate);
				System.out.println(FinalisedTime);
			}
		} catch(ParseException ex) { System.out.println("Date formating error : " + ex); }

		basic b1 = new basic();
		b1.testStatic("Wajiku");
		b1.testStatic("Wangari");

		basic b2 = new basic();
		b2.testStatic("Wangeci");

		String myName = "Dennis  Aaron     Wachira          Gichangi";
		String myNames[] = myName.split(" ");
		for(int i = 0; i < myNames.length; i++) {
			if(myNames[i].trim().length() > 0) System.out.println(i + " = " + myNames[i].trim());
		}
		
		String HashVal = "vuvuzelah967FT21151RW55W21053115239827.006634930017CHQ-107275KENYA NETWORK INFORMATION CENTRESUCCESS";
		b2.getSHA(HashVal);
		b2.sha256_hash(HashVal);
		
		HashVal = "ncba_kenicH1f@Dh!9Uu967FT21151RW55W21053115239827.006634930017CHQ-107275KENYA NETWORK INFORMATION CENTRESUCCESS";
		b2.getSHA(HashVal);
		b2.sha256_hash(HashVal);
	}

	public void testStatic(String newConfig) {
		System.out.println("STATIC TESTING");

		System.out.println("Test 1 : " + basicStatic.getConfig());

	    basicStatic.setConfig(newConfig);

		System.out.println("Test 2 : " + basicStatic.getConfig());
	}
	
	public void getSHA(String input) {
		try {
		    MessageDigest md = MessageDigest.getInstance("SHA-256");
		    byte[] hashIS = md.digest(input.getBytes(StandardCharsets.UTF_8));
		    String encodedString = Base64.getEncoder().encodeToString(hashIS);
		    System.out.println(encodedString);
		} catch(NoSuchAlgorithmException ex) {
			System.out.println("Error NoSuchAlgorithmException : " + ex);
		}
    }
    
    //Hashing Method
	public void sha256_hash(String input) {
		StringBuilder Sb = new StringBuilder();
		try {
		    MessageDigest md = MessageDigest.getInstance("SHA-256");
		    byte[] hashIS = md.digest(input.getBytes(StandardCharsets.UTF_8));
			for (Byte b : hashIS) Sb.append(b.toString());
			
			System.out.println(Sb.toString());
			String encodedString = Base64.getEncoder().encodeToString(Sb.toString().getBytes());
			
			System.out.println(encodedString);
		} catch(NoSuchAlgorithmException ex) {
			System.out.println("Error NoSuchAlgorithmException : " + ex);
		}		
	}

}

