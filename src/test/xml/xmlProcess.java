
import java.io.StringWriter;

import org.w3c.dom.Document;
import org.w3c.dom.Element;

import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.xpath.XPath;
import javax.xml.xpath.XPathConstants;
import javax.xml.xpath.XPathExpressionException;
import javax.xml.xpath.XPathFactory;

import javax.xml.transform.OutputKeys;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerConfigurationException;

public class xmlProcess {

	public static void main(String args[]) {

		try {
			DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
			factory.setNamespaceAware(true);
			DocumentBuilder documentBuilder = factory.newDocumentBuilder();
			Document doc = documentBuilder.newDocument();
			
			doc.setXmlStandalone(true);

			Element envelope = doc.createElement("IR56B");
			envelope.setAttributeNS("http://www.w3.org/2001/XMLSchema-instance", "xsi:noNamespaceSchemaLocation", "ir56b.xsd");

			Element messageNode = doc.createElement("Section");
			messageNode.appendChild(doc.createTextNode("6A1"));
			messageNode.setAttribute("name", "kangura");
			
			Element nameNode = doc.createElement("Section");
			nameNode.appendChild(doc.createTextNode("奥迪普时装(深圳)有限公司"));

			envelope.appendChild(messageNode);
			envelope.appendChild(nameNode);
			doc.appendChild(envelope);

			//toString(envelope);
			toString(doc);
		} catch (ParserConfigurationException e) {
		}
	}

	public static void toString(Document newDoc) {		// Element newDoc) {
		try {
			DOMSource domSource = new DOMSource(newDoc);
			Transformer transformer = TransformerFactory.newInstance().newTransformer();
			transformer.setOutputProperty(OutputKeys.STANDALONE, "yes");
			
			StringWriter sw = new StringWriter();
			StreamResult sr = new StreamResult(sw);
			transformer.transform(domSource, sr);

			System.out.println(sw.toString());  
		} catch (TransformerException ex) {}
	}
	

}
