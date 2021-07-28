import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.DocumentBuilder;
import org.w3c.dom.Document;
import org.w3c.dom.NodeList;
import org.w3c.dom.Node;
import org.w3c.dom.Element;
import java.io.File;

public class xmlRead {

	public static void main(String argv[]) {

		try {
			File fXmlFile = new File("SearchRequest.xml");
			DocumentBuilderFactory dbFactory = DocumentBuilderFactory.newInstance();
			DocumentBuilder dBuilder = dbFactory.newDocumentBuilder();
			Document doc = dBuilder.parse(fXmlFile);

			doc.getDocumentElement().normalize();

			System.out.println("Root element :" + doc.getDocumentElement().getNodeName());
			Node channel = doc.getElementsByTagName("channel").item(0);
			NodeList items = channel.getChildNodes();
			
			for(int j = 0; j < items.getLength(); j++) {
				Node item = items.item(j);
				if(item.getNodeType() == 1) {
					if(item.getNodeName().equals("item")) {
						System.out.println(item.getNodeName());
						System.out.println(item.getNodeType());
					}
				}
			}


		} catch (Exception e) {
			e.printStackTrace();
		}
	}

}
