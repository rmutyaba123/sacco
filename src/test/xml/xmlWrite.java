
import java.io.StringWriter;

import javax.xml.soap.MessageFactory;
import javax.xml.soap.SOAPMessage;
import javax.xml.soap.SOAPHeader;
import javax.xml.soap.SOAPBody;
import javax.xml.soap.SOAPElement;
import javax.xml.soap.SOAPException;

import javax.xml.transform.OutputKeys;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.TransformerException;

public class xmlWrite {

	public static void main(String args[]) {
		try {
			MessageFactory messageFactory = MessageFactory.newInstance();
			SOAPMessage message = messageFactory.createMessage();
			SOAPHeader header = message.getSOAPHeader();
			SOAPBody body = message.getSOAPBody();
			
			SOAPElement sbEl1 = body.addChildElement("CBAPaymentNotificationResult");
			SOAPElement sbEl2 = sbEl1.addChildElement("Result");
			sbEl2.addTextNode("OKAY");
			
			toString(message);
			
		} catch(SOAPException ex) {
			System.out.println(ex);
		}
	}
	
	public static void toString(SOAPMessage message) {		// Element newDoc) {
		try {
			DOMSource domSource = new DOMSource(message.getSOAPPart());
			
			Transformer transformer = TransformerFactory.newInstance().newTransformer();
			transformer.setOutputProperty(OutputKeys.STANDALONE, "yes");
			transformer.setOutputProperty(OutputKeys.INDENT, "yes");
			
			StringWriter sw = new StringWriter();
			StreamResult sr = new StreamResult(sw);
			transformer.transform(domSource, sr);

			System.out.println(sw.toString());  
		} catch (TransformerException ex) {}
	}

	

}
