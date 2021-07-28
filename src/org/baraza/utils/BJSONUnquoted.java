/**
 * @author      Dennis W. Gichangi <dennis@openbaraza.org>
 * @version     2020.0329
 * @since       1.6
 * website		www.openbaraza.org
 * The contents of this file are subject to the GNU Lesser General Public License
 * Version 3.0 ; you may use this file in compliance with the License.
 */
package org.baraza.utils;

import org.json.JSONString;

public class BJSONUnquoted implements JSONString {

    private String string;

    public BJSONUnquoted(String string) {
        this.string = string;
    }

    @Override
    public String toJSONString() {
        return string;
    }

}

