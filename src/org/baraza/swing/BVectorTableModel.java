/**
 * @author      Dennis W. Gichangi <dennis@openbaraza.org>
 * @version     2011.0329
 * @since       1.6
 * website		www.openbaraza.org
 * The contents of this file are subject to the GNU Lesser General Public License
 * Version 3.0 ; you may use this file in compliance with the License.
 */
package org.baraza.swing;

import java.util.Vector;
import java.util.List;
import java.util.Map;

import javax.swing.table.AbstractTableModel;
import javax.swing.event.TableModelEvent;

public class BVectorTableModel extends AbstractTableModel {
	Vector<Vector<String>> myData;
	Vector<String> myTitles;
	boolean editCell = false;

	public BVectorTableModel(Vector<Vector<String>> myData, Vector<String> myTitles) {
		this.myData = myData;
		this.myTitles = myTitles;
	}

    public boolean isCellEditable(int aRow, int aCol) {
		return editCell;
    }

    public void setValueAt(Object value, int aRow, int aCol) {
		myData.get(aRow).set(aCol, value.toString());
		fireTableCellUpdated(aRow, aCol);
	}

	public void removeRow(int aRow) {
		myData.remove(aRow);
		refresh();
	}

	public void refresh() { // Get all rows.
		fireTableChanged(null); // Tell the listeners a new table has arrived.
	}

	public void clear() { // clear all rows.
		myData.clear();
		refresh();
	}

	public int getColumnCount() { return myTitles.size(); }
	public int getRowCount() { return myData.size(); }
	public String getColumnName(int aCol) { return myTitles.get(aCol); }
	public Vector<String> getColumnNames() { return myTitles; }
	public Object getValueAt(int aRow, int aCol) { return myData.get(aRow).get(aCol); }

}

