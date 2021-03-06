/**
 * @author      Dennis W. Gichangi <dennis@openbaraza.org>
 * @version     2011.0329
 * @since       1.6
 * website		www.openbaraza.org
 * The contents of this file are subject to the GNU Lesser General Public License
 * Version 3.0 ; you may use this file in compliance with the License.
 */
package org.baraza.server.tomcat;

import java.util.logging.Logger;
import java.util.List;
import java.io.File;
import java.io.IOException;
import javax.servlet.ServletException;
import java.net.MalformedURLException;

import javax.servlet.Servlet;
import org.apache.catalina.startup.Tomcat;
import org.apache.catalina.core.StandardServer;
import org.apache.catalina.core.AprLifecycleListener;
import org.apache.catalina.Context;
import org.apache.catalina.LifecycleException;
import org.apache.catalina.Wrapper;
import org.apache.tomcat.util.descriptor.web.SecurityConstraint;
import org.apache.tomcat.util.descriptor.web.SecurityCollection;

import org.baraza.DB.BDB;
import org.baraza.xml.BElement;
import org.baraza.utils.BLogHandle;

public class BTomcat extends Thread {
	Logger log = Logger.getLogger(BTomcat.class.getName());
	Tomcat tomcat = null;
	Context context = null;

	public BTomcat(BDB db, BElement root, BLogHandle logHandle, String projectDir) {
		try {
			String ps = System.getProperty("file.separator");
			String basePath = root.getAttribute("base.path", getCurrentDir());
			File dirBasePath = new File(basePath);
			System.out.println("BASE DIR " + dirBasePath.getCanonicalPath());
			String baseDir = dirBasePath.getCanonicalPath() + ps + root.getAttribute("base.dir") + ps;
			String appBase = baseDir + root.getAttribute("app.base") + ps;
			String repository = root.getAttribute("repository") + ps;
			String contextPath = root.getAttribute("contextPath");
			Integer port = new Integer(root.getAttribute("port", "9876"));
		
			tomcat = new Tomcat();
			tomcat.setPort(port);
			tomcat.setBaseDir(baseDir);
			tomcat.enableNaming();

			// Add AprLifecycleListener
			StandardServer server = (StandardServer)tomcat.getServer();
			AprLifecycleListener listener = new AprLifecycleListener();
			server.addLifecycleListener(listener);

			context = tomcat.addWebapp(contextPath, appBase);
			String contextFile = appBase + "META-INF" + ps + "context.xml";
			if(root.getAttribute("context") != null) contextFile = projectDir + ps + "configs" + ps + root.getAttribute("context");
			File configFile = new File(contextFile);
			context.setConfigFile(configFile.toURI().toURL());
			context.addParameter("projectDir", projectDir);
			if(root.getAttribute("init.xml") != null)
				context.addParameter("init_xml", root.getAttribute("init.xml"));
			if(root.getAttribute("login.xml") != null)
				context.addParameter("login_xml", root.getAttribute("login.xml"));
			
			if(repository != null) {
				Context rpContext = tomcat.addWebapp("/repository", baseDir + repository);
				File rpConfigFile = new File(baseDir + repository + "META-INF" + ps + "context.xml");
				rpContext.setConfigFile(rpConfigFile.toURI().toURL());
			}

			tomcat.start();
		} catch(javax.servlet.ServletException ex) {
			log.severe("Tomcat startuo error : " + ex);
		} catch(MalformedURLException ex) {
			log.severe("Tomcat URL Malformation : " + ex);
		} catch(LifecycleException ex) {
			log.severe("Tomcat Life cycle error : " + ex);
		} catch(IOException ex) {
			log.severe("Tomcat IO Exception error : " + ex);
		}
	}
	
	public BTomcat(BElement appEl, String projectDir, String appKey) {
		String ps = System.getProperty("file.separator");
		String basePath = getCurrentDir();
		String baseDir = basePath + ps + "build/webapps" + ps;
		String appBase = baseDir + "baraza" + ps;
		String repository = "repository" + ps;
		String contextPath = "/" + appKey;
		projectDir += ps + appEl.getAttribute("path");
		
		Integer port = new Integer(appEl.getAttribute("port", "9090"));

		try {
			tomcat = new Tomcat();
			tomcat.setPort(port);
			tomcat.setBaseDir(baseDir);
			tomcat.enableNaming();

			// Add AprLifecycleListener
			StandardServer server = (StandardServer)tomcat.getServer();
			AprLifecycleListener listener = new AprLifecycleListener();
			server.addLifecycleListener(listener);

			context = tomcat.addWebapp(contextPath, appBase);
			String contextFile = projectDir + ps + "configs" + ps + "context.xml";
			File configFile = new File(contextFile);
			context.setConfigFile(configFile.toURI().toURL());
			context.addParameter("projectDir", projectDir);
			context.addParameter("init_xml", appEl.getAttribute("xmlfile"));
			
			if(repository != null) {
				Context rpContext = tomcat.addWebapp("/repository", baseDir + repository);
				File rpConfigFile = new File(baseDir + repository + "META-INF" + ps + "context.xml");
				rpContext.setConfigFile(rpConfigFile.toURI().toURL());
			}

			tomcat.start();
		} catch(javax.servlet.ServletException ex) {
			log.severe("Tomcat startuo error : " + ex);
		} catch(MalformedURLException ex) {
			log.severe("Tomcat URL Malformation : " + ex);
		} catch(LifecycleException ex) {
			log.severe("Tomcat Life cycle error : " + ex);
		}
	}

	public void addServlet(String urlPattern, String contextPath, String servletName, Servlet servlet) {
		tomcat.addServlet(contextPath, servletName, servlet);
		context.addServletMappingDecoded(urlPattern, servletName);
	}

	public void addSecurityConstraint(String urlPattern, List<String> roles) {
		SecurityConstraint securityConstraint = new SecurityConstraint();
		for(String role : roles) securityConstraint.addAuthRole(role);
		
		SecurityCollection collection = new SecurityCollection();
		collection.addPattern(urlPattern);
		securityConstraint.addCollection(collection);
		context.addConstraint(securityConstraint);
	}

	public String getCurrentDir() {
		File directory = new File (".");
		String dirName = null;
		try {
			dirName = directory.getCanonicalPath();
		} catch(IOException ex) {
			log.severe("Current directory get error : " + ex);
		}
		return dirName;
	}

	public void run() {
		tomcat.getServer().await();
	}

	public void close() {
		try {
			tomcat.stop();
		} catch(LifecycleException ex) {
			log.severe("Tomcat Life cycle error : " + ex);
		}
	}

}

