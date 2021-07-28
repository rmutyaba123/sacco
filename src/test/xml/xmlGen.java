
import java.io.StringWriter;
import java.util.Map;
import java.util.HashMap;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.OutputKeys;

import org.w3c.dom.Attr;
import org.w3c.dom.Document;
import org.w3c.dom.Element;

public class xmlGen {

	public static void main(String args[]) {
		Map<String, String> params = new HashMap<String, String>();
		params.put("UCNVADIST", "40");
		params.put("UCIVADIST", "70");
		params.put("UCNVAOUDIST", "40");

		XmlGen xmlGen = new XmlGen();
		xmlGen.getXml(params);
	}

	public String getXml(Map<String, String> params) {
		String xmlStr = null;

		try {
			DocumentBuilderFactory docFactory = DocumentBuilderFactory.newInstance();
			DocumentBuilder docBuilder = docFactory.newDocumentBuilder();

			// root elements
			Document doc = docBuilder.newDocument();
			Element rootElement = doc.createElement("formdata");
			doc.appendChild(rootElement);
			for(String param : params.keySet()) {
				Element dataItem = doc.createElement(param);
				dataItem.appendChild(doc.createCDATASection(params.get(param)));
				rootElement.appendChild(dataItem);
			}

			// writting to string
			DOMSource domSource = new DOMSource(doc);
			StringWriter writer = new StringWriter();
			StreamResult result = new StreamResult(writer);
			TransformerFactory tf = TransformerFactory.newInstance();
			Transformer transformer = tf.newTransformer();
			transformer.setOutputProperty(OutputKeys.ENCODING, "UTF-8");
			transformer.setOutputProperty(OutputKeys.INDENT, "yes");
			transformer.transform(domSource, result);
			writer.flush();

		    xmlStr = writer.toString();
System.out.println("BASE " + xmlStr);
		} catch (ParserConfigurationException ex) {
			System.out.println("BASE XML Error " + ex);
		} catch (TransformerException ex) {
			System.out.println("BASE XML Error " + ex);
		}

		return xmlStr;
	}
}
