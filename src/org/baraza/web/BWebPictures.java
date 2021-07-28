/**
 * @author      Dennis W. Gichangi <dennis@openbaraza.org>
 * @version     2011.0329
 * @since       1.6
 * website		www.openbaraza.org
 * The contents of this file are subject to the GNU Lesser General Public License
 * Version 3.0 ; you may use this file in compliance with the License.
 */
package org.baraza.web;

import java.util.logging.Logger;
import java.util.Iterator;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.HashMap;

import java.io.File;
import java.io.PrintWriter;
import java.io.OutputStream;
import java.io.InputStream;
import java.io.IOException;

import org.json.JSONObject;
import org.json.JSONArray;

import org.apache.commons.lang.StringEscapeUtils;
import org.apache.commons.fileupload.servlet.ServletFileUpload;
import org.apache.commons.fileupload.FileItem;
import org.apache.commons.fileupload.FileUploadException;
import org.apache.commons.fileupload.disk.DiskFileItemFactory;

import javax.servlet.ServletContext;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.baraza.DB.BDB;
import org.baraza.DB.BQuery;
import org.baraza.utils.BWebdav;

public class BWebPictures extends HttpServlet {
	Logger log = Logger.getLogger(BWebPictures.class.getName());
	BDB db = null;
	BWebdav webdav = null;
	String photo_access;

	public void doPost(HttpServletRequest request, HttpServletResponse response)  {
		doGet(request, response);
	}

	public void doGet(HttpServletRequest request, HttpServletResponse response) {
		String dbconfig = "java:/comp/env/jdbc/database";
		db = new BDB(dbconfig);

		ServletContext config = this.getServletContext();
		photo_access = config.getInitParameter("photo_access");
		if(photo_access == null) photo_access = "";
		String repository = config.getInitParameter("repository_url");
		String username = config.getInitParameter("rep_username");
		String password = config.getInitParameter("rep_password");
System.out.println("repository : " + repository);
		webdav = new BWebdav(repository, username, password);
		
		/* These URL used as
			barazapictures?access=ob&picture=11pic.jpeg
			delbarazapictures?access=ob&picture=11pic.jpeg
			putbarazapictures		Multipart post with photo segment, you get photo name in json
		*/
		
		String sp = request.getServletPath();
		if(sp.equals("/barazapictures")) showPhoto(request, response);
		if(sp.equals("/delbarazapictures")) delPhoto(request, response);
		if(sp.equals("/putbarazapictures")) putPictures(request, response);

		db.close();
	}

	public void showPhoto(HttpServletRequest request, HttpServletResponse response) {
		String pictureFile = request.getParameter("picture");
		String access = request.getParameter("access");
		InputStream in = webdav.getFile(pictureFile);

		int dot = pictureFile.lastIndexOf(".");
        String ext = pictureFile.substring(dot + 1);

		if((photo_access.equals(access)) && (in != null)) {
			try {
				response.setContentType("image/" + ext);  
				OutputStream out = response.getOutputStream();

				int bufferSize = 1024;
				byte[] buffer = new byte[bufferSize];
				int c = 0;
				while ((c = in.read(buffer)) != -1) out.write(buffer, 0, c);

				in.close();
				out.flush(); 
			} catch(IOException ex) {
				log.severe("IO Error : " + ex);
			}
		}
	}

	public void delPhoto(HttpServletRequest request, HttpServletResponse response) {
		String pictureFile = request.getParameter("picture");
		String access = request.getParameter("access");

		if(photo_access.equals(access))
			webdav.delFile(pictureFile);
	}
	
	public void putPictures(HttpServletRequest request, HttpServletResponse response) {
		System.out.println("Add a baraza picture");
		JSONObject jResp =  new JSONObject();
		
		ServletContext context = this.getServletContext();
		String ps = System.getProperty("file.separator");
		String tmpPath = context.getRealPath("WEB-INF" + ps + "tmp");
		
		int yourMaxMemorySize = 262144;
		File yourTempDirectory = new File(tmpPath);
		DiskFileItemFactory factory = new DiskFileItemFactory(yourMaxMemorySize, yourTempDirectory);
		ServletFileUpload upload = new ServletFileUpload(factory);
		
		Map<String, String> reqParams = new HashMap<String, String>();
		try {
			List items = upload.parseRequest(request);
			Iterator itr = items.iterator();
			while(itr.hasNext()) {
				FileItem item = (FileItem) itr.next();
				if(item.isFormField()) {
					reqParams.put(item.getFieldName(), item.getString());
				} else if(item.getSize() > 0) {
					String pictureFile = savePicture(item, context);
					if(pictureFile != null) {
						reqParams.put(item.getFieldName(), pictureFile);
						jResp.put("picture_name", pictureFile);
						jResp.put("error", false);
					} else {
						jResp.put("error", true);
					}
				}
			}
		} catch (FileUploadException ex) {
			log.severe("File upload exception " + ex);
		}
		
		try {
			PrintWriter out = response.getWriter(); 
			out.println(jResp.toString());
		} catch(IOException ex) {}
		
	}
	
	public String savePicture(FileItem item, ServletContext config) {
		String pictureFile = null;

		String contentType = item.getContentType();
		String fieldName = item.getFieldName();
		String fileName = item.getName();
		long fs = item.getSize();

		long maxfs = 4194304;

		String ext = null;
		int i = fileName.lastIndexOf('.');
		if(i>0 && i<fileName.length()-1) ext = fileName.substring(i+1).toLowerCase();
		if(ext == null) ext = "NAI";
		String pictureName = db.executeFunction("SELECT nextval('picture_id_seq')") + "pic." + ext;

		try {
			String[] imageTypes = {"BMP", "GIF", "JFIF", "JPEG", "JPG", "PNG", "TIF", "TIFF"};
			ext = ext.toUpperCase().trim();

			if(Arrays.binarySearch(imageTypes, ext) >= 0) {
				if(fs < maxfs) {
					webdav.saveFile(item.getInputStream(), pictureName);
					pictureFile = pictureName;
				}
			}
		}  catch(IOException ex) {
			log.severe("File saving failed Exception " + ex);
		}

		return pictureFile;
	}


}
