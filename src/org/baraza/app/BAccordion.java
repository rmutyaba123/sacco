/**
 * @author      Dennis W. Gichangi <dennis@openbaraza.org>
 * @version     2019.0329
 * @since       3.6
 * website		www.openbaraza.org
 * The contents of this file are subject to the GNU Lesser General Public License
 * Version 3.0 ; you may use this file in compliance with the License.
 */
package org.baraza.app;

import java.util.logging.Logger;
import java.util.Map;
import java.util.HashMap;
import java.util.List;
import java.util.ArrayList;

import javax.swing.JTabbedPane;
import javax.swing.JPanel;

import org.baraza.swing.BTextIcon;
import org.baraza.DB.BDB;
import org.baraza.xml.BElement;
import org.baraza.utils.BLogHandle;

public class BAccordion extends JTabbedPane {
	Logger log = Logger.getLogger(BGrids.class.getName());
	BLogHandle logHandle;
	
	BElement view;
	BDB db;
	List<BTabs> tabs;
	List<BGrids> grids;
	List<BForm> forms;

	public BAccordion(BLogHandle logHandle, BDB db, BElement view, String reportDir) {
		super(JTabbedPane.LEFT);
		
		this.db = db;
		this.view = view;
		this.logHandle = logHandle;
		logHandle.config(log);
		
		tabs = new ArrayList<BTabs>();
		grids = new ArrayList<BGrids>();
		forms = new ArrayList<BForm>();
		
		for(BElement el : view.getElements()) {
			if(el.getName().equals("FORM")) {
				forms.add(new BForm(logHandle, db, el));
				forms.get(forms.size() -1).moveFirst();
				tabs.add(new BTabs(1, forms.size()-1));
				
				BTextIcon textIcon = new BTextIcon(this, el.getAttribute("name"), BTextIcon.ROTATE_RIGHT);
				addTab("", textIcon, forms.get(forms.size() -1));
			} else if(el.getName().equals("GRID") || el.getName().equals("FORMVIEW")) {
				grids.add(new BGrids(logHandle, db, el, reportDir, false));
				tabs.add(new BTabs(2, grids.size()-1));
				
				BTextIcon textIcon = new BTextIcon(this, el.getAttribute("name"), BTextIcon.ROTATE_RIGHT);
				addTab("", textIcon, grids.get(grids.size() -1));
			}
		}
	}

}
