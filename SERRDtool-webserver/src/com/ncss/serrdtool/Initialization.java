package com.ncss.serrdtool;


import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;



public class Initialization implements ServletContextListener{
	static String path = System.getProperty("catalina.home") + "/webapps/SERRDtool/WEB-INF/";
	static String configFile = path + "reasoning/input/Config/SERRD_config.xml";
	static String cloudFile = path + "reasoning/input/Config/cloud_config.xml";
	static String cloudFact = path + "reasoning/input/Config/cloud.clp";
	static String metaFile = path + "reasoning/input/Config/meta_config.xml";
	static String metaFact = path + "reasoning/input/Config/meta.clp";
	static String fileName = "Ontology_V1.06_rdf";
	static String xslFileName = path + "reasoning/tool/OWL2Jess.xsl";
	static String xmlFileName = path + "reasoning/input/ontology/" + fileName +".owl";
	static String outOFxslFileName = path + "reasoning/input/ontology/transformed/" + fileName +".clp";
	static String redirectFileName = path + "reasoning/input/ontology/redirect.clp";
	static String shortedName = path + "reasoning/input/ontology/" + fileName + "_short.clp";
	private Connection conn;
	private Statement stmt;

	public void contextInitialized(ServletContextEvent arg0)
    {

		parseConfig();
		
		generateCLP(outOFxslFileName);

		owl_jess(xslFileName, xmlFileName, outOFxslFileName);
		
		factShortener(outOFxslFileName, shortedName);
		
		initDB();
		
		parseCloud();
		
		parseMeta();
    	
    }//end contextInitialized method


    public void contextDestroyed(ServletContextEvent arg0) 
    {   
    }//end constextDestroyed method
    
    public void parseConfig(){
    	  org.w3c.dom.Document doc = GetDocfile(configFile);
    	  DBConfigParser(doc);  	    	  
    }
    
    public void generateCLP(String output)
	{//redirect to the final ontology facts
    	try {
    		PrintWriter writer = new PrintWriter(new FileWriter(redirectFileName), true);
    		String line = "(batch \"" + output + "\")";
    		writer.println(line);
    		writer.close();
    	} catch(IOException e) {
    		e.printStackTrace();
    	}
	}
	
	public void owl_jess(String xsl, String xml, String output)
	{//translate owl to clp
		try {
			TransformerFactory tFactory = TransformerFactory.newInstance();
			
			Transformer transformer = tFactory.newTransformer(new StreamSource(xsl));

			transformer.transform(new StreamSource(xml), new StreamResult(new FileOutputStream(output)));
    	
			//System.out.println("************* The result is in : reasoning/" + outOFxslFileName + " *************");
		} catch (TransformerException | IOException e) {
			e.printStackTrace();
		}

	}
	
	public void factShortener(String inFile, String outFile) {
		
		String[] triple = new String[3];
		
		try {
			BufferedReader read = new BufferedReader(new FileReader(inFile));
			BufferedWriter write = new BufferedWriter(new FileWriter(outFile));

			//first get the prefix: usually it's the first block in clp file and can be easily recganized
			
			String prefix  = getPrefix(read, write);
			
			// eliminate prefix from each concept node
			// by using the same BufferedReader, the prefix information is still reserved by the first triple
			while(loadTriple(read, triple) != 0) {
				for(int i = 0; i < triple.length; ++i) {
					if(triple[i].indexOf(prefix) > 0) { // contains prefix
						int m = triple[i].indexOf('\"');
						int n = triple[i].indexOf('#');
						StringBuilder temp = new StringBuilder();
						temp.append(triple[i].subSequence(0, m+1));
						temp.append(triple[i].subSequence(n+1, triple[i].length()));
						triple[i] = temp.toString();
					}
				}
				writeFact(write, triple);
				//System.out.println();
			}
			
			read.close();
			write.close();
		} catch (IOException e) {
			e.printStackTrace();
		}
		
	}
	
	public void initDB() {
		try {
			
			createDB();
			
			createTables();
			
		} catch (ClassNotFoundException e) {
			e.printStackTrace();
		} catch (SQLException e) {
			e.printStackTrace();
		} 
	}
	
	public void parseCloud() {
  	    CloudParser(cloudFile, cloudFact);
	}
	
	public void parseMeta() {
  	    MetaParser(metaFile, metaFact);
	}
	
	//-------------------- helper functions for parseConfig --------------------
	
	private   org.w3c.dom.Document GetDocfile(String filename)
    {
        org.w3c.dom.Document doc = null;
        
            File fXmlFile = new File(filename);
            DocumentBuilderFactory dbFactory = DocumentBuilderFactory.newInstance();
            DocumentBuilder dBuilder = null;
			try {
				dBuilder = dbFactory.newDocumentBuilder();
			} catch (ParserConfigurationException e) {
				e.printStackTrace();
			}
            try {
				doc = dBuilder.parse(fXmlFile);
			} catch (SAXException e) {
				e.printStackTrace();
			} catch (IOException e) {
				e.printStackTrace();
			}
            doc.getDocumentElement().normalize();
        
        return doc;
    }
	
	public void DBConfigParser(org.w3c.dom.Document doc) {
		  NodeList nList = doc.getElementsByTagName("db");     //list of db config
	  	  for (int temp = 0; temp < nList.getLength(); temp++) {
	  		  Node nNode = nList.item(temp);
	  		  if (nNode.getNodeType() == Node.ELEMENT_NODE) {
	  			  Element eElement = (Element)nNode;		// db nodes
	  			  String dbName = eElement.getAttribute("name");
	  			  if(dbName.equals("SEMANTICS")) {
	  				String host = eElement.getElementsByTagName("host").item(0).getTextContent(); 
	  				String user = eElement.getElementsByTagName("user").item(0).getTextContent();
	  				String password = eElement.getElementsByTagName("password").item(0).getTextContent(); 
	  				Config.db_host = host;
	  				Config.db_user = user;
	  				Config.db_password = password;
	  			  }
	  		  }
	  	  }
	}
	
	//-------------------- helper functions for parseCloud --------------------
	public void CloudParser(String input, String output) {
		//TODO
		org.w3c.dom.Document doc = GetDocfile(input);
		try {
			BufferedWriter writer = new BufferedWriter(new FileWriter(output));
			NodeList nList = doc.getElementsByTagName("Cloud");     //list of cloud config
	  	  	for (int temp = 0; temp < nList.getLength(); temp++) {
	  	  		Node nNode = nList.item(temp);
	  	  		if (nNode.getNodeType() == Node.ELEMENT_NODE) {
	  	  			Element eElement = (Element)nNode;		// db nodes
	  	  				  	  			
	  	  			NodeList dcList = eElement.getElementsByTagName("DataCenter");     //list of datacenter config
	  	  			for (int tempdc = 0; tempdc < dcList.getLength(); tempdc++) {
	  	  				Node dcNode = dcList.item(tempdc);
	  	  				if (dcNode.getNodeType() == Node.ELEMENT_NODE) {
	  	  					Element dcElement = (Element)dcNode;		// db nodes
	  	  					String dcName = dcElement.getAttribute("name");
	  	  					
	  	  					NodeList clList = dcElement.getElementsByTagName("Cluster");     //list of cluster config
	  	  					String dcFact = "";
	  	  					for (int tempcl = 0; tempcl < clList.getLength(); tempcl++) {
	  	  						Node clNode = clList.item(tempcl);
	  	  						if (clNode.getNodeType() == Node.ELEMENT_NODE) {
	  	  							Element clElement = (Element)clNode;		// db nodes
	  	  							String clName = clElement.getAttribute("name");
	  	  							dcFact += clName + " ";
	  	  							
	  	  							NodeList hoList = clElement.getElementsByTagName("Host");     //list of host config
	  	  							String clFact = "";
	  	  							for (int tempho = 0; tempho < hoList.getLength(); tempho++) {
	  	  								Node hoNode = hoList.item(tempho);
	  	  								if (hoNode.getNodeType() == Node.ELEMENT_NODE) {
	  	  									Element hoElement = (Element)hoNode;		// db nodes
	  	  									String hoName = hoElement.getAttribute("name");
	  	  									clFact += hoName + " ";
	  	  									
	  	  									NodeList vmList = hoElement.getElementsByTagName("VM");     //list of host config
	  	  									String hoFact = "";
	  	  									for (int tempvm = 0; tempvm < vmList.getLength(); tempvm++) {
	  	  										Node vmNode = vmList.item(tempvm);
	  	  										if (vmNode.getNodeType() == Node.ELEMENT_NODE) {
	  	  											Element vmElement = (Element)vmNode;		// db nodes
	  	  											String vmName = vmElement.getAttribute("name");
	  	  											hoFact += vmName + " ";
		  	  									
	  	  										}
	  	  									}//for VM
	  	  									writeHost(writer, hoName, hoFact.trim());
	  	  									
	  	  								}
	  	  								
	  	  							}//for host
	  	  							writeCluster(writer, clName, clFact.trim());
		  	  					
	  	  						}
	  	  					}//for cluster
	  	  					writeDataCenter(writer, dcName, dcFact.trim());
	  	  					
	  	  				}
	  	  			}// for datacenter

	  	  		}
	  	  	}// for cloud
	  	  	writer.close();
		} catch(IOException e) {
			e.printStackTrace();
		}
	}
	
	private void writeDataCenter(BufferedWriter w, String dc, String cl) {
		try {
			w.write("(assert\n");
			w.write("  (dataCenter\n");
			
			w.write("    (name " + dc + ")\n");
			w.write("    (cluster " + cl + ")\n");
			
			w.write("  )\n");
			w.write(")\n\n");
		} catch(IOException e) {
			e.printStackTrace();
		}
	}
	
	private void writeCluster(BufferedWriter w, String cl, String ho) {
		try {
			w.write("(assert\n");
			w.write("  (cluster\n");
			
			w.write("    (name " + cl + ")\n");
			w.write("    (host " + ho + ")\n");
			
			w.write("  )\n");
			w.write(")\n\n");
		} catch(IOException e) {
			e.printStackTrace();
		}
	}
	
	private void writeHost(BufferedWriter w, String ho, String vm) {
		try {
			w.write("(assert\n");
			w.write("  (host\n");
			
			w.write("    (name " + ho + ")\n");
			w.write("    (VM " + vm + ")\n");
			
			w.write("  )\n");
			w.write(")\n\n");
		} catch(IOException e) {
			e.printStackTrace();
		}
	}
	
	//-------------------- helper functions for parseMeta --------------------
	public void MetaParser(String input, String output) {
		//TODO
		org.w3c.dom.Document doc = GetDocfile(input);
		try{
			BufferedWriter writer = new BufferedWriter(new FileWriter(output));
			NodeList nList = doc.getElementsByTagName("meta");     //list of meta config
			//System.out.println("meta: " + nList.getLength());
	  	  	for (int temp = 0; temp < nList.getLength(); temp++) {
	  	  		Node nNode = nList.item(temp);
	  	  		if (nNode.getNodeType() == Node.ELEMENT_NODE) {
	  	  			Element eElement = (Element)nNode;		// db nodes
	  	  			String handle = eElement.getElementsByTagName("handle").item(0).getTextContent();
	  	  			String path = eElement.getElementsByTagName("path").item(0).getTextContent();
	  	  			String DSName = eElement.getElementsByTagName("DSName").item(0).getTextContent();
	  	  			String CF = eElement.getElementsByTagName("DSName").item(0).getTextContent();
	  	  			String quantitativeDefinition = eElement.getElementsByTagName("quantitativeDefinition").item(0).getTextContent();
	  	  			String metricName = eElement.getElementsByTagName("metricName").item(0).getTextContent();
	  	  			String unitName = eElement.getElementsByTagName("unitName").item(0).getTextContent();
	  	  			String unit = eElement.getElementsByTagName("unit").item(0).getTextContent();
	  	  			String entityType = eElement.getElementsByTagName("entityType").item(0).getTextContent();
	  	  			String entity = eElement.getElementsByTagName("entity").item(0).getTextContent();
	  	  			String startTime = eElement.getElementsByTagName("startTime").item(0).getTextContent();
	  	  			String endTime = eElement.getElementsByTagName("endTime").item(0).getTextContent();
	  	  			String rows = eElement.getElementsByTagName("rows").item(0).getTextContent();
	  	  			String step = eElement.getElementsByTagName("step").item(0).getTextContent();
	  	  			Meta m = new Meta(handle, path, DSName, CF, quantitativeDefinition, metricName, unitName, unit, entityType, entity, Long.valueOf(startTime), Long.valueOf(endTime), Integer.valueOf(rows), Integer.valueOf(step));
	  	  			writeMeta(writer, m);
	  	  			add2DB(m);
	  	  		}
	  	  	}
	  	  	writer.close();
		} catch(IOException e) {
			e.printStackTrace();
		}
	}
	
	private void writeMeta(BufferedWriter w, Meta m) {
		try {
			w.write("(assert\n");
			w.write("  (meta\n");
			
			if(m.getHandle().length() != 0) {
				w.write("    (handle " + m.getHandle() + ")\n");
			}
			
			if(m.getPath().length() != 0) {
				w.write("    (path " + m.getPath() + ")\n");
			}
			
			if(m.getDSName().length() != 0) {
				w.write("    (DSName " + m.getDSName() + ")\n");
			}
			
			if(m.getCF().length() != 0) {
				w.write("    (CF " + m.getCF() + ")\n");
			}
			
			//w.write("    (quantitativeDefinition " + m.quantitativeDefinition + ")\n");
			if(m.getMetricName().length() != 0) {
				w.write("    (metricName " + m.getMetricName() + ")\n");
			}
			
			if(m.getUnitName().length() != 0) {
				w.write("    (unitName " + m.getUnitName() + ")\n");
			}
			
			if(m.getUnit().length() != 0) {
				w.write("    (unit " + m.getUnit() + ")\n");
			}
			
			if(m.getEntityType().length() != 0) {
				w.write("    (entityType " + m.getEntityType() + ")\n");
			}
			
			if(m.getEntity().length() != 0) {
				w.write("    (entity " + m.getEntity() + ")\n");
			}
			
			if(m.getStartTime().length() != 0) {
				w.write("    (startTime " + m.getStartTime() + ")\n");
			}
			
			if(m.getEndTime().length() != 0) {
				w.write("    (endTime " + m.getEndTime() + ")\n");
			}
			
			if(m.getRows().length() != 0) {
				w.write("    (rows " + m.getRows() + ")\n");
			}
			
			if(m.getStep().length() != 0) {
				w.write("    (step " + m.getStep() + ")\n");
			}
			
			
			w.write("  )\n");
			w.write(")\n\n");
		} catch(IOException e) {
			e.printStackTrace();
		}
	}
	
	private void add2DB(Meta m) {
		String sql = "INSERT INTO META (handle,path,metricName,DSName,CF,quantitativeDefinition,unitName,unit,entityType,entity,startTime,endTime,rows,step) " +
                "VALUES ('abcdefghijklmnh', 'abcdefghijklmnh.rrd', 'abcdefghijklmnh', 'abcdefgh', 'AVERAGE', 'definition', 'percent', 18, 'host', 'host0001', 1478644958, 1478645318, 72, 5) ON DUPLICATE KEY UPDATE metricName='abcdefghijklmnh'";
		try {
			conn = initSQL("jdbc:mysql://","SEMANTICS") ;
			stmt = conn.createStatement();
			stmt.executeUpdate(sql);
					
		} catch (SQLException e){
			e.printStackTrace();
		} finally {
			try{
				if(stmt != null) {
		            stmt.close();
				}
				if (conn != null) {
					closeSQL(conn);
				}
			} catch (SQLException e1) {
				e1.printStackTrace();
			}
			
			//System.out.println("Instances inserted.");
		}
	}
	
	// ------------ helper functions for factShortener ----------
		
	private void writeFact(BufferedWriter write, String[] triple) {
		try {
			write.write("(assert\n");
			write.write("  (triple\n");
			
			write.write("    " + triple[0] + "\n");
			write.write("    " + triple[1] + "\n");
			write.write("    " + triple[2] + "\n");
			
			write.write("  )\n");
			write.write(")\n\n");
		} catch(IOException e) {
			e.printStackTrace();
		}
	}
	
	private String getPrefix(BufferedReader read, BufferedWriter write) {
		String prefix = "";
			
		String[] triple = new String[3];
		
		while(loadTriple(read, triple) != 0) {
			int m = triple[0].indexOf('#');
			int n = triple[2].indexOf('#');
			if(triple[0].substring(m+1, triple[0].length()).equals("type\")")
					&& triple[2].substring(n+1, triple[2].length()).equals("Ontology\")")) { // identification of prefix by ontology declaration
				int p = triple[1].indexOf('\"');	
				int q = triple[1].lastIndexOf('\"');
				prefix = triple[1].substring(p+1, q);
				writeFact(write, triple);
				return prefix;
			}
		}
		
		
		return prefix;
	}
	
	private int loadTriple(BufferedReader read, String[] triple) {
		// if there is a new triple, then return 1, else return 0
		String line = "";
		int result = 0;
		try {
			
			while((line = read.readLine()) != null) {
				if(line.trim().length() == 0) {
					continue;
				}
				if(line.trim().equals("(assert")) {
					result = 1;
					if(read.readLine().trim().equals("(triple")) {
						triple[0] = read.readLine().trim(); // predicate
						triple[1] = read.readLine().trim(); // subject
						triple[2] = read.readLine().trim(); // object
						read.readLine();
						read.readLine();
						return result;
					}
				}
			}
		
		} catch(IOException e) {
			e.printStackTrace();
		}
		
		return result;
	}
	
	
	// ------------ helper functions for initDB ------
	private Connection initSQL(String dbURL, String dbName)
	{// init sql connection
		try {
			Class.forName("com.mysql.jdbc.Driver").newInstance();
			if(dbName.equals("")) {
				conn = DriverManager.getConnection(dbURL + Config.db_host, Config.db_user, Config.db_password);
			}
			else {
				conn = DriverManager.getConnection(dbURL + Config.db_host+"/" + dbName, Config.db_user, Config.db_password);
			}
		} catch (InstantiationException | IllegalAccessException e1) {
			e1.printStackTrace();
		} catch (ClassNotFoundException e2) {
			e2.printStackTrace();
		} catch (SQLException e3) {
			e3.printStackTrace();
		}
		
		//System.out.println("Initializing.");
		return conn;
	}
	
	private void createDB() throws SQLException {
		String sql = "CREATE DATABASE IF NOT EXISTS SEMANTICS";
		try {
			conn = initSQL("jdbc:mysql://","");
			stmt = conn.createStatement();
			stmt.executeUpdate(sql);
			
		} catch(SQLException e2) {
			e2.printStackTrace();
		} finally {
			if(stmt!=null) {
	            stmt.close();
			}
			if (null != conn) {
				closeSQL(conn);
			}
			//System.out.println("Database created.");
		}
	}
	
	private void createTables() throws SQLException, ClassNotFoundException {
		String sql = "CREATE TABLE IF NOT EXISTS META " +
                "(handle VARCHAR(15) not NULL, " +
                " path VARCHAR(4096), " + 
                " metricName VARCHAR(255), " +
                " DSName VARCHAR(255), " +
                " CF VARCHAR(255), " +
                " quantitativeDefinition VARCHAR(4096), " + 
                " unitName VARCHAR(255), " + 
                " unit INT, " + 
                " entityType VARCHAR(255), " + 
                " entity VARCHAR(255), " + 
                " startTime BIGINT, " + 
                " endTime BIGINT, " + 
                " rows INT, " + 
                " step INT, " + 
                " PRIMARY KEY ( handle ))";  
		try {
			conn = initSQL("jdbc:mysql://","SEMANTICS");
			stmt = conn.createStatement();
			stmt.executeUpdate(sql);
							
			insertMeta();
			
		} finally {
			if(stmt != null) {
	            stmt.close();
			}
			if (conn != null) {
				closeSQL(conn);
			}
			//System.out.println("Table created.");
		}
	}
	
	private void insertMeta() throws ClassNotFoundException, SQLException {
		String sql = "INSERT INTO META (handle,path,metricName,DSName,CF,quantitativeDefinition,unitName,unit,entityType,entity,startTime,endTime,rows,step) " +
                   "VALUES ('abcdefghijklmnh', 'abcdefghijklmnh.rrd', 'abcdefghijklmnh', 'abcdefgh', 'AVERAGE', 'definition', 'percent', 18, 'host', 'host0001', 1478644958, 1478645318, 72, 5) ON DUPLICATE KEY UPDATE metricName='abcdefghijklmnh'";
		try {
			conn = initSQL("jdbc:mysql://","SEMANTICS") ;
			stmt = conn.createStatement();
			stmt.executeUpdate(sql);
					
		} finally {
			if(stmt != null) {
	            stmt.close();
			}
			if (conn != null) {
				closeSQL(conn);
			}
			//System.out.println("Instances inserted.");
		}
	}

	private void closeSQL(Connection connection) throws SQLException 
	{// close sql connection
		if (!connection.isClosed()) {
			connection.close();
		}
	}
}
