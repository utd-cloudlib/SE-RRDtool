/****************************************************************************
 * RRDtool 1.4.9  Copyright by Tobi Oetiker, 1997-2014
 ****************************************************************************
 * rrd_rpncalc.c  RPN calculator functions
 ****************************************************************************/

#include <limits.h>
#include <locale.h>
#include <stdlib.h>

#include "rrd_tool.h"
#include "rrd_rpncalc.h"
// #include "rrd_graph.h"

// <<<<<<<<<<< modified by Shuai
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <json/json.h>
#include <curl/curl.h>
#include <dirent.h>
#include <libxml/parser.h>
#include <libxml/tree.h>

#define MAX_FILE_NAME_LENGTH 4096
#define MAX_DS_NAME_LENGTH 20
#define MAX_FIELD_LENGTH 50
#define HANDLE_LENGTH 16
#define IP_LENGTH 16
#define PORT_LENGTH 4

// holder for curl fetch
struct curl_fetch_st {
    char *payload;
    size_t size;
};

struct curl_reasoning_st {
    char handle[HANDLE_LENGTH];
    size_t size_h;
    char quantitativeDefinition[MAX_FILE_NAME_LENGTH];
    size_t size_q;
    char name[MAX_DS_NAME_LENGTH];
    size_t size_n;
};

struct web_service {
    char url[MAX_FILE_NAME_LENGTH];
    char IP[IP_LENGTH];
    char port[PORT_LENGTH];
};

struct semantic {
    char metricName[MAX_FILE_NAME_LENGTH];
    char DSName[MAX_DS_NAME_LENGTH];
    char CF[MAX_DS_NAME_LENGTH];
    char unitName[MAX_FIELD_LENGTH];
    char unit[MAX_FIELD_LENGTH];
    char entityType[MAX_FIELD_LENGTH];
    char entity[MAX_FIELD_LENGTH];
    char startTime[MAX_FIELD_LENGTH];
    char endTime[MAX_FIELD_LENGTH];
    char rows[MAX_FIELD_LENGTH];
    char step[MAX_FIELD_LENGTH];
};

struct se_config {
    char url[MAX_FILE_NAME_LENGTH];
    char path[MAX_FILE_NAME_LENGTH];
};

const char* config_file = "../conf.xml";
const char* url_pre = "/SERRDtool/reasoning/WebService/metas";
const int num_functions = 15;
const char* valid_functions[] = {
	"dump", "info", "restore", "last", "lastupdate",
	 "first", "update", "updatev", "fetch", "flushcached",
	 "graph", "graphv", "tune", "resize", "xport"
};

const int num_args = 3;
const char* valid_args[] = {"-un", "-et","-en"};

// function declearation
size_t curl_callback (void *contents, size_t size, size_t nmemb, void *userp);
CURLcode curl_fetch_url(CURL *ch, const char *url, struct curl_fetch_st *fetch);
struct curl_reasoning_st json_parse(json_object * jobj);
struct curl_reasoning_st getFileName(struct semantic s, struct se_config sc);
int check_function(char* cmd, const char** list, int num);
void parseXML(char* file, struct se_config *sc);
void parseNode_Conf(xmlNode* node, struct web_service *ws);
void parseNode_WS(xmlNode* node, struct web_service *ws);
void parseNode_repository(xmlNode* node, char* path);
void parseNode_path(xmlNode* node, char* path);
void parse_error(char* s);
void arg_free(char** arg);

// check valide commands
int check_function(char* cmd, const char** list, int num) {
    int i;
    for(i = 0; i < num; ++i ) {
        if(!strcmp(cmd, list[i])) {
            //printf("Valid!\n");
	    return 1;
        }
    }
    return 0;
}

// callback for curl fetch
size_t curl_callback (void *contents, size_t size, size_t nmemb, void *userp) {
    size_t realsize = size * nmemb;                             // calculate buffer size
    struct curl_fetch_st *p = (struct curl_fetch_st *) userp;   // cast pointer to fetch struct 

    p->payload = (char *) realloc(p->payload, p->size + realsize + 1);

    if (p->payload == NULL) {
      fprintf(stderr, "ERROR: Failed to expand buffer in curl_callback");
      free(p->payload);
      return -1;
    }

    memcpy(&(p->payload[p->size]), contents, realsize);

    p->size += realsize;

    p->payload[p->size] = 0;

    return realsize;
}

// fetch and return url body via curl
CURLcode curl_fetch_url(CURL *ch, const char *url, struct curl_fetch_st *fetch) {
    CURLcode rcode;                   // curl result code

    fetch->payload = (char *) calloc(1, sizeof(fetch->payload));

    if (fetch->payload == NULL) {
        fprintf(stderr, "ERROR: Failed to allocate payload in curl_fetch_url");
        return CURLE_FAILED_INIT;
    }


    fetch->size = 0;

    curl_easy_setopt(ch, CURLOPT_URL, url);

    curl_easy_setopt(ch, CURLOPT_WRITEFUNCTION, curl_callback);

    curl_easy_setopt(ch, CURLOPT_WRITEDATA, (void *) fetch);

    curl_easy_setopt(ch, CURLOPT_TIMEOUT, 5);

    curl_easy_setopt(ch, CURLOPT_FOLLOWLOCATION, 1);

    curl_easy_setopt(ch, CURLOPT_MAXREDIRS, 1);

    rcode = curl_easy_perform(ch);

    return rcode;
}

struct curl_reasoning_st json_parse(json_object * jobj) {
    enum json_type type;
    struct curl_reasoning_st res;
    json_object_object_foreach(jobj, key, val) {
      type = json_object_get_type(val);
      switch (type) {
      case json_type_string: 	
	if(strcmp(key, "DSName") == 0) {
	    strcpy(res.name, json_object_get_string(val));
	    res.size_n = strlen(res.name);
	}
	else if(strcmp(key, "quantitativeDefinition") == 0) {
	    strcpy(res.quantitativeDefinition, json_object_get_string(val));
	    res.size_q = strlen(res.quantitativeDefinition);
	}
     	break;
      case json_type_int:
	if(strcmp(key, "handle") == 0) {
	    sprintf(res.handle, "%d", json_object_get_int(val));
	    res.size_h = strlen(res.handle);
	}
        break;
      }
      
    }
    return res;
}

struct curl_reasoning_st getFileName(struct semantic s, struct se_config sc) {
    // request for web service to get semantic reference
    //char DSName[MAX_DS_NAME_LENGTH];
    CURL *ch;                                               // curl handle
    CURLcode rcode;                                         // curl result code

    json_object *json;                                      // json post body
    enum json_tokener_error jerr = json_tokener_success;    // json parse error

    struct curl_fetch_st curl_fetch;                        // curl fetch struct
    struct curl_fetch_st *cf = &curl_fetch;                 // pointer to fetch struct
    struct curl_slist *headers = NULL;                      // http headers to send with reqeust
    struct curl_reasoning_st res;		    // parsed result

    // url to test site
    char *url = (char*)malloc(sizeof(char)*MAX_FILE_NAME_LENGTH);
    if(url == NULL) {
        rrd_set_error("can't allocate memory");
        return res;
    }
    //strcpy(url, url_pre);
    strcpy(url, sc.url);

    strcat(url, "?metricName=");
    strcat(url, s.metricName);
    strcat(url, "&DSName=");
    strcat(url, s.DSName);
    strcat(url, "&CF=");
    strcat(url, s.CF);
    strcat(url, "&unitName=");
    strcat(url, s.unitName);
    strcat(url, "&unit=");
    strcat(url, s.unit);
    strcat(url, "&entityType=");
    strcat(url, s.entityType);
    strcat(url, "&entity=");
    strcat(url, s.entity);
    strcat(url, "&startTime=");
    strcat(url, s.startTime);
    strcat(url, "&endTime=");
    strcat(url, s.endTime);
    strcat(url, "&rows=");
    strcat(url, s.rows);
    strcat(url, "&step=");
    strcat(url, s.step);
    //printf("URL for query: %s\n", url);

    if ((ch = curl_easy_init()) == NULL) {
        fprintf(stderr, "ERROR: Failed to create curl handle in fetch_session");
        return res;
    }

    // set content type
    headers = curl_slist_append(headers, "Accept: application/json");
    headers = curl_slist_append(headers, "Content-Type: application/json");

    // create json object for post
    json = json_object_new_object();

    curl_easy_setopt(ch, CURLOPT_HTTPHEADER, headers);

    curl_easy_setopt(ch, CURLOPT_HTTPGET, 1L);

    rcode = curl_fetch_url(ch, url, cf);

    curl_easy_cleanup(ch);

    curl_slist_free_all(headers);

    // free json object
    json_object_put(json);

    // check return code 
    if (rcode != CURLE_OK || cf->size < 1) {
        fprintf(stderr, "ERROR: Failed to fetch url (%s) - curl said: %s",
            url, curl_easy_strerror(rcode));

        return res;
    }

    // check payload
    if (cf->payload != NULL) {
        //printf("CURL Returned: \n%s\n", cf->payload);

        json = json_tokener_parse(cf->payload);
	res = json_parse(json);

        free(cf->payload);
    } else {
        fprintf(stderr, "ERROR: Failed to populate payload");
        free(cf->payload);
 
        return res;
    }

    // check error
    if (jerr != json_tokener_success) {
        fprintf(stderr, "ERROR: Failed to parse json string");

        json_object_put(json);

        return res;
    }

    //printf("Parsed JSON: %s\n", json_object_to_json_string(json));
    free(url);

    return res;
}

void parse_error(char* s) {
  fprintf(stderr, "%s\n", s);
}

void parseNode_WS(xmlNode* node, struct web_service *ws) {
  xmlNode* cur = NULL;

  for(cur = node; cur; cur = cur->next) {
    if(cur->type == XML_ELEMENT_NODE) {
      if(strcmp(cur->name, "url") == 0) {
	//printf("Parsing URL... \n");
	if(xmlNodeGetContent(cur->children) != NULL) {
	  strcpy(ws->url, xmlNodeGetContent(cur->children));
	}
	//printf("URL parsed. \n");	
      }
      else if(strcmp(cur->name, "serverIP") == 0) {
	//printf("Parsing serverIP... \n");
	if(xmlNodeGetContent(cur->children) != NULL) {
            strcpy(ws->IP, xmlNodeGetContent(cur->children));
	}
	//printf("serverIP parsed. \n");
      }
      else if(strcmp(cur->name, "serverPort") == 0) {
	//printf("Parsing serverPort... \n");
	if(xmlNodeGetContent(cur->children) != NULL) {
            strcpy(ws->port, xmlNodeGetContent(cur->children));
	}
	//printf("serverPort parsed. \n");
      }
      parseNode_WS(cur->children, ws);
    }
  }
}

void parseNode_URL(xmlNode* node, struct web_service *ws) {
  xmlNode* cur = NULL;

  for(cur = node; cur; cur = cur->next) {
    if(cur->type == XML_ELEMENT_NODE) {
      if(strcmp(cur->name, "webService") == 0) {
        parseNode_WS(cur->children, ws);  // only parse WebService subtree
      }
      else {
        parseNode_URL(cur->children, ws);
      }
    }
  }
}

void parseNode_repository(xmlNode* node, char* path) {
  xmlNode* cur = NULL;

  for(cur = node; cur; cur = cur->next) {
    if(cur->type == XML_ELEMENT_NODE) {
      if(strcmp(cur->name, "path") == 0) {
	//printf("Parsing path... \n");
	if(xmlNodeGetContent(cur->children) != NULL) {
	  strcpy(path, xmlNodeGetContent(cur->children));
	}
	//printf("Path parsed. \n");	
      }

      parseNode_repository(cur->children, path);
    }
  }
}

void parseNode_path(xmlNode* node, char* path) {
  xmlNode* cur = NULL;

  for(cur = node; cur; cur = cur->next) {
    if(cur->type == XML_ELEMENT_NODE) {
      if(strcmp(cur->name, "repository") == 0) {
        parseNode_repository(cur->children, path);  // only parse repository subtree
      }
      else {
        parseNode_path(cur->children, path);
      }
    }
  }
}

void parseXML(char* file, struct se_config *sc) {
  //printf("Parseing configuration...\n");
  int len = strlen(file);
  if(file[len-4] != '.' || file[len-3] != 'x' || file[len-2] != 'm' || file[len-1] != 'l') {
    return; // only parse xml file
  }
  xmlDoc* doc = xmlReadFile(file, NULL, 0);
  xmlNode* cur = NULL;

  if(doc == NULL) {
    parse_error("File parse failed.");
    return;
  }

  cur = xmlDocGetRootElement(doc);
  if(cur == NULL) {
    parse_error("Empty file.");
    return;
  }

  // parse url
  char url[MAX_FILE_NAME_LENGTH];
  struct web_service ws;
  parseNode_URL(cur, &ws);
  if(strlen(ws.url)) {
    strcpy(url, ws.url);
    strcat(url, url_pre);
  }
  else {
    strcpy(url, "http://");
    strcat(url, ws.IP);
    strcat(url, ":");
    strcat(url, ws.port);
    strcat(url, url_pre);
  }
  strcpy(sc->url, url);

  // parse path
  char path[MAX_FILE_NAME_LENGTH];
  parseNode_path(cur, path);
  strcpy(sc->path, path);

  xmlFreeDoc(doc);

  //printf("File %s has been parsed.\n\n\n", file);
}

char** redirect(int argc, char** argv, int optind) {
    // optind is the index of the file name to be operated in argv
    char fullPath[MAX_FILE_NAME_LENGTH];
    char dumpPath[MAX_FILE_NAME_LENGTH];
    char fileName[MAX_FILE_NAME_LENGTH];
    char buff[MAX_FILE_NAME_LENGTH];
    char DSName[MAX_DS_NAME_LENGTH];
    char unitName[MAX_FIELD_LENGTH];
    char unit[MAX_FIELD_LENGTH];
    char entityType[MAX_FIELD_LENGTH];
    char entity[MAX_FIELD_LENGTH];

    char **result = NULL;

    int ind, indv, loc = -1, i, j, loc_DS = 0, mem_size = 0, len = 0, itr, mark = 0;
    int offset[argc];
    char c;
    int new_argc;

    if(argc < 3) {
        rrd_set_error("need name of an rrd file to create");
        return result;
    }

    for(i = 0; i < argc; ++i) {
	offset[i] = 0;
    }
    printf("Start redirect.");
    int mode = 1; // 1 for normal mode, 2 for SE mode with meta, 3 for SE mode with handle
    for(ind = 0; ind < argc; ++ind) {
	if(strcmp(argv[ind], "-se") == 0) {
	    mode = 2;
	    new_argc = argc - 7;
	}
	else if(strcmp(argv[ind], "-sh") == 0) {
	    mode = 3;
	    new_argc = argc - 1;
	}
    }


    if(mode == 1) { // normal mode
	return result;
    }

    struct se_config sc;
    parseXML(config_file,  &sc); // get the semantic configuration

    printf("Get XML with mode %d \n.", mode);

    if(mode == 2) { // -se unitName -un unit -et entityType -en entity
	// SE mode with meta

	result = (char**)malloc(sizeof(char*) * new_argc);

    	if(result == NULL) {
	    rrd_set_error("allocating unknown");
	    return result;
    	}

	// parse general parameters
	strcpy(unitName, argv[2]);

	itr = 3;

	while(check_function(argv[itr], valid_args, num_args)) {
	    if(strcmp(argv[itr], "-un") == 0) {
		strcpy(unit, argv[itr+1]);
		printf("unit: %d \t %s \n", strlen(unit), unit);
	    }
	    else if(strcmp(argv[itr], "-et") == 0) {
		strcpy(entityType, argv[itr+1]);
		printf("entityType: %d \t %s \n", strlen(entityType), entityType);
	    }
	    else if(strcmp(argv[itr], "-en") == 0) {
		strcpy(entity, argv[itr+1]);
		printf("entity: %d \t %s \n", strlen(entity), entity);
	    }

	    itr = itr + 2;
	}


    	if(!strcmp(argv[0], "create")) {
	    strcpy(fullPath, argv[itr]); // now itr points to file name

    	    // get ds name
	    for(ind = itr; ind < argc; ++ind) {
		if(strncmp(argv[ind], "DS:", 3) == 0) {
	    	    for(i = 0; i < MAX_DS_NAME_LENGTH; ++i) {
			c = argv[ind][3+i];
			if(c == ':') break;
			DSName[i] = c;
	    	    }
	    	    DSName[i] = '\0';
	    	    loc_DS = 3 + i; // now loc_DS points to the next ':' after original DSName
	    	    break;
		}
    	    }

    	    // get file name: assume in SE mode, just metricName is input, without extension name ".rrd"
    	    for(ind = 0; ind < MAX_FILE_NAME_LENGTH; ++ind) {
        	c = fullPath[i];
		if(c == '\0') break;
		if(c == '/') {
	    	    loc = ind;
		}
    	    }

    	    if(loc >= 0) { // loc is the last '/' in the full path
		for(ind = 0; ind < MAX_FILE_NAME_LENGTH; ++ind) {
	    	    c = fullPath[loc+ind+1];
	    	    if(c == '\0') break;
	    	    fileName[ind] = c;
        	}
        	fileName[ind] = '\0';
    	    }
    	    else { // just file name
		strcpy(fileName, fullPath);
    	    }

    	    // get file name and ds name from web service
    	    //if(!strcmp(argv[0], "create")) { // optind - 1 is the index of function
        	/*strcpy(DSName, fileName);
		len = strlen(DSName);
		if(len == MAX_DS_NAME_LENGTH) {
	    	    DSName[len - 1] = '\0'; // ensure null termination 
		}*/

	    // till now we have DSName, fileName (metricName), unitName, unit, entityType and entity
	    struct semantic meta;
	    strcpy(meta.metricName, fileName);
	    strcpy(meta.DSName, DSName);
	    strcpy(meta.CF, "nil"); // label unknown as "nil"
	    strcpy(meta.unitName, unitName);
	    strcpy(meta.unit, unit);
	    strcpy(meta.entityType, entityType);
	    strcpy(meta.entity, entity);
	    strcpy(meta.startTime, "nil");
	    strcpy(meta.endTime, "nil");
	    strcpy(meta.rows, "nil");
	    strcpy(meta.step, "nil");
	    printf("Get meta ready.");
	    struct curl_reasoning_st res = getFileName(meta, sc); // get 
	    printf("Get reasoning result.");


            strcpy(fileName, res.handle);
	    strcat(fileName, ".rrd");
	    //strcpy(DSName, res.DSName);
    	    //}
    	    //else {
        	//strcpy(fileName, "testMetric.rrd");        
    	    //}

    	    // mock names
    	    // strcpy(fileName, "testname.rrd");
    	    // strcpy(DSName, "metric");

    	    // reconstruct the new full file path
    	    /*for(ind = 0; ind < MAX_FILE_NAME_LENGTH; ++ind) {
		c = fileName[ind];
		if(c == '\0') break;
		fullPath[loc+ind+1] = c;
    	    }
    	    fullPath[loc+ind+1] = '\0';*/

	    strcpy(fullPath, sc.path);
	    strcat(fullPath, fileName);

    	    // reconstruct arguments
	    // allocate space
	    offset[0] = res.size_q + 1;  //quantitativeDefinition
	    mem_size += offset[0];
	    offset[1] = strlen(argv[0]) + 1; // function, i.e. create, fetch
	    mem_size += offset[1];
    	    for(ind = 2, indv = itr; indv < argc; ++ind, ++indv) {
		if(indv == itr) { // path
	    	    offset[ind] = strlen(fullPath) + 1; // new file absolute path
		}
		else if(strncmp(argv[indv], "DS:", 3) == 0) { // DS
	    	    offset[ind] = 3 + strlen(DSName) + strlen(argv[indv]) - loc_DS + 1;
		}
		else {
	    	    offset[ind] = strlen(argv[indv]) + 1;
		}
		mem_size += offset[ind];
    	    }

    	    result[0] = (char*)malloc(sizeof(char) * mem_size);
    	    if(result[0] == NULL) {
		// error processing while malloc
		rrd_set_error("allocating unknown");
		return result;
    	    }
    	    for(ind = 1; ind < new_argc; ++ind) {
		result[ind] = result[ind - 1] + offset[ind - 1];
    	    }
	    printf("Memory allocated.\n");

	    // update arguments
	    strcpy(result[0], res.quantitativeDefinition);
	    strcpy(result[1], argv[0]);
	    strcpy(result[2], fullPath);
    	    for(ind = 3, indv = itr + 1; indv < argc; ++ind, ++indv) {
		if(strncmp(argv[indv], "DS:", 3) == 0) {
	    	    strcpy(buff, argv[indv]);
	    	    strcpy(result[ind], "DS:");
	    	    for(i = 0; i < MAX_DS_NAME_LENGTH; ++i) {
			c = DSName[i];
			if(c == '\0') break;
			result[ind][3+i] = c;
	    	    }

	    	    for(j = 0; j < MAX_DS_NAME_LENGTH; ++j) {
			c = buff[loc_DS+j];
			if(c == '\0') break;
			result[ind][3+i+j] = c;
	    	    }
	    	    result[ind][3+i+j] = '\0';
		}
		else {
	    	    strcpy(result[ind], argv[indv]);
		}
    	    }
	    printf("Get new argument.");

	    // store the redirected result if it's new
	    strcpy(fullPath, sc.path);
	    strcat(fullPath, "metaList.txt");

	    FILE * fp;

	    fp = fopen(fullPath, "a");
	    fprintf(fp, "\n------------------------------------------------------\n");
	    fprintf(fp, "  handle:       %s\n", res.handle);
	    fprintf(fp, "  metricName:   %s\n", meta.metricName);
	    fprintf(fp, "  unitName:     %s\n", meta.unitName);
	    fprintf(fp, "  unit:         %s\n", meta.unit);
	    fprintf(fp, "  entityType:   %s\n", meta.entityType);
	    fprintf(fp, "  entity:       %s\n", meta.entity);
	    fprintf(fp, "  DSName:       %s\n", meta.DSName);
	    fprintf(fp, "  CF:           %s\n", meta.CF);

	    fclose(fp);

	
    	} // end if create
	else if(!strcmp(argv[0], "graph") || !strcmp(argv[0], "graphv") || !strcmp(argv[0], "xport")) {
	
	} // end if graph, graphv, xport
	else if(!strcmp(argv[0], "flushcached")) {
	
	} // end if flushcached
    	else if(check_function(argv[0], valid_functions, num_functions)) {
	
    	}
    	else {
	    rrd_set_error("unknown function.");
            return NULL;
    	}
    } // end SE mode with meta
    else if(mode == 3){
	// SE mode with handle: just remove handle
	if(!strcmp(argv[0], "graph") || !strcmp(argv[0], "graphv") || !strcmp(argv[0], "xport")) {
	    result = (char**)malloc(sizeof(char*) * (argc - 1));
	    //new_argc = argc - 1;  // remove "-sh"
    	    if(result == NULL) {
	        rrd_set_error("allocating unknown");
	        return result;
    	    }	

	    // reconstruct arguments
	    // allocate space
	    loc = 0;
	    itr = 2; 
	    mem_size = 0;
	    offset[0] = strlen(argv[0]) + 1; // function, i.e. create, fetch
    	    for(ind = 1, indv = itr; indv < argc; ++ind, ++indv) {
		if(strncmp(argv[indv], "DEF:", 4) == 0) { // path
	    	    offset[ind] = strlen(argv[indv]) + strlen(sc.path) + 5;
		}
		else {
	    	    offset[ind] = strlen(argv[indv]) + 1;
		}
		mem_size += offset[ind];
    	    }


    	    result[0] = (char*)malloc(sizeof(char) * mem_size);
    	    if(result[0] == NULL) {
		// error processing while malloc
		rrd_set_error("allocating unknown");
		return result;
    	    }
    	    for(ind = 1; ind < new_argc; ++ind) {
		result[ind] = result[ind - 1] + offset[ind - 1];
    	    }

	    // update arguments
	    strcpy(result[0], argv[0]);
    	    for(ind = 1, indv = itr; indv < argc; ++ind, ++indv) {
		if(strncmp(argv[indv], "DEF:", 4) == 0) {
		    mark = 0;		 
		    len = strlen(argv[indv]);
		    for(i = 0, j = 0; i <= len; ++i, ++j) { // process and copy the DEFs in the argument
			if(argv[indv][i] == '=') {
			    dumpPath[j] = argv[indv][i];
			    dumpPath[++j] = '\0';
			    strcat(dumpPath, sc.path);
			    j = strlen(dumpPath) - 1;
			}
			else if(argv[indv][i] == ':') {
			    if(!mark) {
				mark = 1;
				dumpPath[j++] = '.';
				dumpPath[j++] = 'r';
				dumpPath[j++] = 'r';
				dumpPath[j++] = 'd';
				dumpPath[j] = ':';
			    }
			    else {
				dumpPath[j] = argv[indv][i];
			    }
			}
			else  if(argv[indv][i] == '\0'){
			    dumpPath[j] = '\0';
			}
			else {
			    dumpPath[j] = argv[indv][i];
			}
		    }
printf("new def: %s \n", dumpPath);
		    
	    	    strcpy(result[ind], dumpPath);
		}
		else {
	    	    strcpy(result[ind], argv[indv]);
		}
    	    }
	} // end if graph, graphv, xport
	else if(!strcmp(argv[0], "flushcached")) {
	
	} // end if flushcached
	else if(!strcmp(argv[0], "dump")) {
	    result = (char**)malloc(sizeof(char*) * (argc - 1));
	    //new_argc = argc - 1;  // remove "-sh"
    	    if(result == NULL) {
	        rrd_set_error("allocating unknown");
	        return result;
    	    }	
	    strcpy(fileName, argv[2]);
	    strcat(fileName, ".rrd");
	    strcpy(fullPath, sc.path);
	    strcat(fullPath, fileName);

	    // reconstruct arguments
	    // allocate space
	    loc = 0;
	    itr = 2; 
	    mem_size = 0;
	    offset[0] = strlen(argv[0]) + 1; // function, i.e. create, fetch
    	    for(ind = 1, indv = itr; indv < argc; ++ind, ++indv) {
		if(indv == itr) { // path
	    	    offset[ind] = strlen(fullPath) + 1;
		}
		else if(loc > 0) {
		    len = strlen(fullPath);
		    strcpy(dumpPath, fullPath);
		    dumpPath[len -3] = 'x';
		    dumpPath[len -2] = 'm';
		    dumpPath[len -1] = 'l';
		    offset[ind] = strlen(dumpPath) + 1;
		    loc = 0;
		}
		else if(strcmp(argv[indv], ">") == 0) {
		    offset[ind] = strlen(argv[indv]) + 1;
		    loc = indv;
		}
		else {
	    	    offset[ind] = strlen(argv[indv]) + 1;
		}
		mem_size += offset[ind];
    	    }


    	    result[0] = (char*)malloc(sizeof(char) * mem_size);
    	    if(result[0] == NULL) {
		// error processing while malloc
		rrd_set_error("allocating unknown");
		return result;
    	    }
    	    for(ind = 1; ind < new_argc; ++ind) {
		result[ind] = result[ind - 1] + offset[ind - 1];
    	    }

	    // update arguments
	    strcpy(result[0], argv[0]);
    	    for(ind = 1, indv = itr; indv < argc; ++ind, ++indv) {
		if(ind == 1) {
	    	    strcpy(result[ind], fullPath);
		}
		else if(loc > 0) {
		    strcpy(result[ind], dumpPath);
		    loc = 0;
		}
		else if(strcmp(argv[indv], ">") == 0) {
		    strcpy(result[ind], argv[indv]);
		    loc = indv;
		}
		else {
	    	    strcpy(result[ind], argv[indv]);
		}
    	    }

	} // end if dump
	else if(!strcmp(argv[0], "restore")) {
	    result = (char**)malloc(sizeof(char*) * (argc - 1));
	    //new_argc = argc - 1;  // remove "-sh"
    	    if(result == NULL) {
	        rrd_set_error("allocating unknown");
	        return result;
    	    }
	    strcpy(fileName, argv[2]);
	    strcpy(dumpPath, sc.path);
	    strcat(dumpPath, fileName);	

	    // reconstruct arguments
	    // allocate space
	    itr = 2; 
	    mem_size = 0;
	    offset[0] = strlen(argv[0]) + 1; // function, i.e. create, fetch
    	    for(ind = 1, indv = itr; indv < argc; ++ind, ++indv) {
		if(ind == 2) { // path
		    len = strlen(dumpPath);
		    strcpy(fullPath, dumpPath);
		    fullPath[len -3] = 'r';
		    fullPath[len -2] = 'r';
		    fullPath[len -1] = 'd';
	    	    offset[ind] = strlen(fullPath) + 1;
		}
		else if(ind == 1) {
		    offset[ind] = strlen(dumpPath) + 1;
		}
		else {
	    	    offset[ind] = strlen(argv[indv]) + 1;
		}
		mem_size += offset[ind];
    	    }


    	    result[0] = (char*)malloc(sizeof(char) * mem_size);
    	    if(result[0] == NULL) {
		// error processing while malloc
		rrd_set_error("allocating unknown");
		return result;
    	    }
    	    for(ind = 1; ind < new_argc; ++ind) {
		result[ind] = result[ind - 1] + offset[ind - 1];
    	    }

	    // update arguments
	    strcpy(result[0], argv[0]);
    	    for(ind = 1, indv = itr; indv < argc; ++ind, ++indv) {
		if(ind == 1) {
	    	    strcpy(result[ind], dumpPath);
		}
		else if(ind == 2) {
		    strcpy(result[ind], fullPath);
		}
		else {
	    	    strcpy(result[ind], argv[indv]);
		}
    	    }
	} // end if restore
    	else if(check_function(argv[0], valid_functions, num_functions)) {
	    result = (char**)malloc(sizeof(char*) * (argc - 1));
	    //new_argc = argc - 1;  // remove "-sh"
    	    if(result == NULL) {
	        rrd_set_error("allocating unknown");
	        return result;
    	    }

	    strcpy(fileName, argv[2]);
	    strcat(fileName, ".rrd");
	    strcpy(fullPath, sc.path);
	    strcat(fullPath, fileName);
	    // reconstruct arguments
	    // allocate space
	    itr = 2; 
	    mem_size = 0;
	    offset[0] = strlen(argv[0]) + 1; // function, i.e. create, fetch
    	    for(ind = 1, indv = itr; indv < argc; ++ind, ++indv) {
		if(indv == itr) { // path
	    	    offset[ind] = strlen(fullPath) + 1;
		}
		else {
	    	    offset[ind] = strlen(argv[indv]) + 1;
		}
		mem_size += offset[ind];
    	    }


    	    result[0] = (char*)malloc(sizeof(char) * mem_size);
    	    if(result[0] == NULL) {
		// error processing while malloc
		rrd_set_error("allocating unknown");
		return result;
    	    }
    	    for(ind = 1; ind < new_argc; ++ind) {
		result[ind] = result[ind - 1] + offset[ind - 1];
    	    }

	    // update arguments
	    strcpy(result[0], argv[0]);
    	    for(ind = 1, indv = itr; indv < argc; ++ind, ++indv) {
		if(ind == 1) {
	    	    strcpy(result[ind], fullPath);
		}
		else {
	    	    strcpy(result[ind], argv[indv]);
		}
    	    }
    	}
    	else {
	    rrd_set_error("unknown function.");
            return NULL;
    	}
    } // end SE mode with handle    

    return result;
}

void arg_free(char** arg) {
    free(arg[0]);
    free(arg);
}
// >>>>>>>>>>> modified by Shuai


short     addop2str(
    enum op_en op,
    enum op_en op_type,
    char *op_str,
    char **result_str,
    unsigned short *offset);
int       tzoffset(
    time_t);            /* used to implement LTIME */

short rpn_compact(
    rpnp_t *rpnp,
    rpn_cdefds_t **rpnc,
    short *count)
{
    short     i;

    *count = 0;
    /* count the number of rpn nodes */
    while (rpnp[*count].op != OP_END)
        (*count)++;
    if (++(*count) > DS_CDEF_MAX_RPN_NODES) {
        rrd_set_error("Maximum %d RPN nodes permitted. Got %d RPN nodes at present.",
                      DS_CDEF_MAX_RPN_NODES-1,(*count)-1);
        return -1;
    }

    /* allocate memory */
    *rpnc = (rpn_cdefds_t *) calloc(*count, sizeof(rpn_cdefds_t));
    for (i = 0; rpnp[i].op != OP_END; i++) {
        (*rpnc)[i].op = (char) rpnp[i].op;
        if (rpnp[i].op == OP_NUMBER) {
            /* rpnp.val is a double, rpnc.val is a short */
            double    temp = floor(rpnp[i].val);

			if (temp < SHRT_MIN || temp > SHRT_MAX || temp != rpnp[i].val) {
                rrd_set_error
                    ("constants must be integers in the interval (%d, %d)",
                     SHRT_MIN, SHRT_MAX);
                free(*rpnc);
                return -1;
            }
            (*rpnc)[i].val = (short) temp;
        } else if (rpnp[i].op == OP_VARIABLE || rpnp[i].op == OP_PREV_OTHER) {
            (*rpnc)[i].val = (short) rpnp[i].ptr;
        }
    }
    /* terminate the sequence */
    (*rpnc)[(*count) - 1].op = OP_END;
    return 0;
}

rpnp_t   *rpn_expand(
    rpn_cdefds_t *rpnc)
{
    short     i;
    rpnp_t   *rpnp;

    /* DS_CDEF_MAX_RPN_NODES is small, so at the expense of some wasted
     * memory we avoid any reallocs */
    rpnp = (rpnp_t *) calloc(DS_CDEF_MAX_RPN_NODES, sizeof(rpnp_t));
    if (rpnp == NULL) {
        rrd_set_error("failed allocating rpnp array");
        return NULL;
    }
    for (i = 0; rpnc[i].op != OP_END; ++i) {
        rpnp[i].op = (enum op_en)rpnc[i].op;
        if (rpnp[i].op == OP_NUMBER) {
            rpnp[i].val = (double) rpnc[i].val;
        } else if (rpnp[i].op == OP_VARIABLE || rpnp[i].op == OP_PREV_OTHER) {
            rpnp[i].ptr = (long) rpnc[i].val;
        }
    }
    /* terminate the sequence */
    rpnp[i].op = OP_END;
    return rpnp;
}

/* rpn_compact2str: convert a compact sequence of RPN operator nodes back
 * into a CDEF string. This function is used by rrd_dump.
 * arguments:
 *  rpnc: an array of compact RPN operator nodes
 *  ds_def: a pointer to the data source definition section of an RRD header
 *   for lookup of data source names by index
 *  str: out string, memory is allocated by the function, must be freed by the
 *   the caller */
void rpn_compact2str(
    rpn_cdefds_t *rpnc,
    ds_def_t *ds_def,
    char **str)
{
    unsigned short i, offset = 0;
    char      buffer[7];    /* short as a string */

    for (i = 0; rpnc[i].op != OP_END; i++) {
        if (i > 0)
            (*str)[offset++] = ',';

#define add_op(VV,VVV) \
	  if (addop2str((enum op_en)(rpnc[i].op), VV, VVV, str, &offset) == 1) continue;

        if (rpnc[i].op == OP_NUMBER) {
            /* convert a short into a string */
#if defined(_WIN32) && !defined(__CYGWIN__) && !defined(__CYGWIN32__)
            _itoa(rpnc[i].val, buffer, 10);
#else
            sprintf(buffer, "%d", rpnc[i].val);
#endif
            add_op(OP_NUMBER, buffer)
        }

        if (rpnc[i].op == OP_VARIABLE) {
            char     *ds_name = ds_def[rpnc[i].val].ds_nam;

            add_op(OP_VARIABLE, ds_name)
        }

        if (rpnc[i].op == OP_PREV_OTHER) {
            char     *ds_name = ds_def[rpnc[i].val].ds_nam;

            add_op(OP_VARIABLE, ds_name)
        }
#undef add_op

#define add_op(VV,VVV) \
	  if (addop2str((enum op_en)rpnc[i].op, VV, #VVV, str, &offset) == 1) continue;

        add_op(OP_ADD, +)
            add_op(OP_SUB, -)
            add_op(OP_MUL, *)
            add_op(OP_DIV, /)
            add_op(OP_MOD, %)
            add_op(OP_SIN, SIN)
            add_op(OP_COS, COS)
            add_op(OP_LOG, LOG)
            add_op(OP_FLOOR, FLOOR)
            add_op(OP_CEIL, CEIL)
            add_op(OP_EXP, EXP)
            add_op(OP_DUP, DUP)
            add_op(OP_EXC, EXC)
            add_op(OP_POP, POP)
            add_op(OP_LT, LT)
            add_op(OP_LE, LE)
            add_op(OP_GT, GT)
            add_op(OP_GE, GE)
            add_op(OP_EQ, EQ)
            add_op(OP_IF, IF)
            add_op(OP_MIN, MIN)
            add_op(OP_MAX, MAX)
            add_op(OP_LIMIT, LIMIT)
            add_op(OP_UNKN, UNKN)
            add_op(OP_UN, UN)
            add_op(OP_NEGINF, NEGINF)
            add_op(OP_NE, NE)
            add_op(OP_PREV, PREV)
            add_op(OP_INF, INF)
            add_op(OP_ISINF, ISINF)
            add_op(OP_NOW, NOW)
            add_op(OP_LTIME, LTIME)
            add_op(OP_TIME, TIME)
            add_op(OP_ATAN2, ATAN2)
            add_op(OP_ATAN, ATAN)
            add_op(OP_SQRT, SQRT)
            add_op(OP_SORT, SORT)
            add_op(OP_REV, REV)
            add_op(OP_TREND, TREND)
            add_op(OP_TRENDNAN, TRENDNAN)
            add_op(OP_PREDICT, PREDICT)
            add_op(OP_PREDICTSIGMA, PREDICTSIGMA)
            add_op(OP_RAD2DEG, RAD2DEG)
            add_op(OP_DEG2RAD, DEG2RAD)
            add_op(OP_AVG, AVG)
            add_op(OP_ABS, ABS)
            add_op(OP_ADDNAN, ADDNAN)
            add_op(OP_MINNAN, MINNAN)
            add_op(OP_MAXNAN, MAXNAN)
#undef add_op
    }
    (*str)[offset] = '\0';

}

short addop2str(
    enum op_en op,
    enum op_en op_type,
    char *op_str,
    char **result_str,
    unsigned short *offset)
{
    if (op == op_type) {
        short     op_len;

        op_len = strlen(op_str);
        *result_str = (char *) rrd_realloc(*result_str,
                                           (op_len + 1 +
                                            *offset) * sizeof(char));
        if (*result_str == NULL) {
            rrd_set_error("failed to alloc memory in addop2str");
            return -1;
        }
        strncpy(&((*result_str)[*offset]), op_str, op_len);
        *offset += op_len;
        return 1;
    }
    return 0;
}

void parseCDEF_DS(
    const char *def,
    rrd_t *rrd,
    int ds_idx)
{
    rpnp_t   *rpnp = NULL;
    rpn_cdefds_t *rpnc = NULL;
    short     count, i;

    rpnp = rpn_parse((void *) rrd, def, &lookup_DS);
    if (rpnp == NULL) {
        rrd_set_error("failed to parse computed data source");
        return;
    }
    /* Check for OP nodes not permitted in COMPUTE DS.
     * Moved this check from within rpn_compact() because it really is
     * COMPUTE DS specific. This is less efficient, but creation doesn't
     * occur too often. */
    for (i = 0; rpnp[i].op != OP_END; i++) {
        if (rpnp[i].op == OP_TIME || rpnp[i].op == OP_LTIME ||
            rpnp[i].op == OP_PREV || rpnp[i].op == OP_COUNT ||
            rpnp[i].op == OP_TREND || rpnp[i].op == OP_TRENDNAN ||
            rpnp[i].op == OP_PREDICT || rpnp[i].op ==  OP_PREDICTSIGMA ) {
            rrd_set_error
                ("operators TIME, LTIME, PREV COUNT TREND TRENDNAN PREDICT PREDICTSIGMA are not supported with DS COMPUTE");
            free(rpnp);
            return;
        }
    }
    if (rpn_compact(rpnp, &rpnc, &count) == -1) {
        free(rpnp);
        return;
    }
    /* copy the compact rpn representation over the ds_def par array */
    memcpy((void *) &(rrd->ds_def[ds_idx].par[DS_cdef]),
           (void *) rpnc, count * sizeof(rpn_cdefds_t));
    free(rpnp);
    free(rpnc);
}

/* lookup a data source name in the rrd struct and return the index,
 * should use ds_match() here except:
 * (1) need a void * pointer to the rrd
 * (2) error handling is left to the caller
 */
long lookup_DS(
    void *rrd_vptr,
    char *ds_name)
{
    unsigned int i;
    rrd_t    *rrd;

    rrd = (rrd_t *) rrd_vptr;

    for (i = 0; i < rrd->stat_head->ds_cnt; ++i) {
        if (strcmp(ds_name, rrd->ds_def[i].ds_nam) == 0)
            return i;
    }
    /* the caller handles a bad data source name in the rpn string */
    return -1;
}

/* rpn_parse : parse a string and generate a rpnp array; modified
 * str2rpn() originally included in rrd_graph.c
 * arguments:
 * key_hash: a transparent argument passed to lookup(); conceptually this
 *    is a hash object for lookup of a numeric key given a variable name
 * expr: the string RPN expression, including variable names
 * lookup(): a function that retrieves a numeric key given a variable name
 */
rpnp_t   *rpn_parse(
    void *key_hash,
    const char *const expr_const,
    long      (*lookup) (void *,
                         char *))
{
    int       pos = 0;
    char     *expr;
    long      steps = -1;
    rpnp_t   *rpnp;
    char      vname[MAX_VNAME_LEN + 10];
    char     *old_locale;

    old_locale = setlocale(LC_NUMERIC, "C");

    rpnp = NULL;
    expr = (char *) expr_const;

    while (*expr) {
        if ((rpnp = (rpnp_t *) rrd_realloc(rpnp, (++steps + 2) *
                                           sizeof(rpnp_t))) == NULL) {
            setlocale(LC_NUMERIC, old_locale);
            return NULL;
        }

        else if ((sscanf(expr, "%lf%n", &rpnp[steps].val, &pos) == 1)
                 && (expr[pos] == ',')) {
            rpnp[steps].op = OP_NUMBER;
            expr += pos;
        }
#define match_op(VV,VVV) \
        else if (strncmp(expr, #VVV, strlen(#VVV))==0 && ( expr[strlen(#VVV)] == ',' || expr[strlen(#VVV)] == '\0' )){ \
            rpnp[steps].op = VV; \
            expr+=strlen(#VVV); \
    	}

#define match_op_param(VV,VVV) \
        else if (sscanf(expr, #VVV "(" DEF_NAM_FMT ")",vname) == 1) { \
          int length = 0; \
          if ((length = strlen(#VVV)+strlen(vname)+2, \
              expr[length] == ',' || expr[length] == '\0') ) { \
             rpnp[steps].op = VV; \
             rpnp[steps].ptr = (*lookup)(key_hash,vname); \
             if (rpnp[steps].ptr < 0) { \
                           rrd_set_error("variable '%s' not found",vname);\
			   free(rpnp); \
			   return NULL; \
			 } else expr+=length; \
          } \
        }

        match_op(OP_ADD, +)
            match_op(OP_SUB, -)
            match_op(OP_MUL, *)
            match_op(OP_DIV, /)
            match_op(OP_MOD, %)
            match_op(OP_SIN, SIN)
            match_op(OP_COS, COS)
            match_op(OP_LOG, LOG)
            match_op(OP_FLOOR, FLOOR)
            match_op(OP_CEIL, CEIL)
            match_op(OP_EXP, EXP)
            match_op(OP_DUP, DUP)
            match_op(OP_EXC, EXC)
            match_op(OP_POP, POP)
            match_op(OP_LTIME, LTIME)
            match_op(OP_LT, LT)
            match_op(OP_LE, LE)
            match_op(OP_GT, GT)
            match_op(OP_GE, GE)
            match_op(OP_EQ, EQ)
            match_op(OP_IF, IF)
            match_op(OP_MIN, MIN)
            match_op(OP_MAX, MAX)
            match_op(OP_LIMIT, LIMIT)
            /* order is important here ! .. match longest first */
            match_op(OP_UNKN, UNKN)
            match_op(OP_UN, UN)
            match_op(OP_NEGINF, NEGINF)
            match_op(OP_NE, NE)
            match_op(OP_COUNT, COUNT)
            match_op_param(OP_PREV_OTHER, PREV)
            match_op(OP_PREV, PREV)
            match_op(OP_INF, INF)
            match_op(OP_ISINF, ISINF)
            match_op(OP_NOW, NOW)
            match_op(OP_TIME, TIME)
            match_op(OP_ATAN2, ATAN2)
            match_op(OP_ATAN, ATAN)
            match_op(OP_SQRT, SQRT)
            match_op(OP_SORT, SORT)
            match_op(OP_REV, REV)
            match_op(OP_TREND, TREND)
            match_op(OP_TRENDNAN, TRENDNAN)
            match_op(OP_PREDICT, PREDICT)
            match_op(OP_PREDICTSIGMA, PREDICTSIGMA)
            match_op(OP_RAD2DEG, RAD2DEG)
            match_op(OP_DEG2RAD, DEG2RAD)
            match_op(OP_AVG, AVG)
            match_op(OP_ABS, ABS)
            match_op(OP_ADDNAN, ADDNAN)
            match_op(OP_MINNAN, MINNAN)
            match_op(OP_MAXNAN, MAXNAN)
#undef match_op
            else if ((sscanf(expr, DEF_NAM_FMT "%n", vname, &pos) == 1)
                     && ((rpnp[steps].ptr = (*lookup) (key_hash, vname)) !=
                         -1)) {
            rpnp[steps].op = OP_VARIABLE;
            expr += pos;
        }

        else {
            rrd_set_error("don't undestand '%s'",expr);
            setlocale(LC_NUMERIC, old_locale);
            free(rpnp);
            return NULL;
        }

        if (*expr == 0)
            break;
        if (*expr == ',')
            expr++;
        else {
            setlocale(LC_NUMERIC, old_locale);
            free(rpnp);
            return NULL;
        }
    }
    rpnp[steps + 1].op = OP_END;
    setlocale(LC_NUMERIC, old_locale);
    return rpnp;
}

void rpnstack_init(
    rpnstack_t *rpnstack)
{
    rpnstack->s = NULL;
    rpnstack->dc_stacksize = 0;
    rpnstack->dc_stackblock = 100;
}

void rpnstack_free(
    rpnstack_t *rpnstack)
{
    if (rpnstack->s != NULL)
        free(rpnstack->s);
    rpnstack->dc_stacksize = 0;
}

static int rpn_compare_double(
    const void *x,
    const void *y)
{
    double    diff = *((const double *) x) - *((const double *) y);

    return (diff < 0) ? -1 : (diff > 0) ? 1 : 0;
}

/* rpn_calc: run the RPN calculator; also performs variable substitution;
 * moved and modified from data_calc() originally included in rrd_graph.c 
 * arguments:
 * rpnp : an array of RPN operators (including variable references)
 * rpnstack : the initialized stack
 * data_idx : when data_idx is a multiple of rpnp.step, the rpnp.data pointer
 *   is advanced by rpnp.ds_cnt; used only for variable substitution
 * output : an array of output values; OP_PREV assumes this array contains
 *   the "previous" value at index position output_idx-1; the definition of
 *   "previous" depends on the calling environment
 * output_idx : an index into the output array in which to store the output
 *   of the RPN calculator
 * returns: -1 if the computation failed (also calls rrd_set_error)
 *           0 on success
 */
short rpn_calc(
    rpnp_t *rpnp,
    rpnstack_t *rpnstack,
    long data_idx,
    rrd_value_t *output,
    int output_idx)
{
    int       rpi;
    long      stptr = -1;

    /* process each op from the rpn in turn */
    for (rpi = 0; rpnp[rpi].op != OP_END; rpi++) {
        /* allocate or grow the stack */
        if (stptr + 5 > rpnstack->dc_stacksize) {
            /* could move this to a separate function */
            rpnstack->dc_stacksize += rpnstack->dc_stackblock;
            rpnstack->s = (double*)rrd_realloc(rpnstack->s,
                                      (rpnstack->dc_stacksize) *
                                      sizeof(*(rpnstack->s)));
            if (rpnstack->s == NULL) {
                rrd_set_error("RPN stack overflow");
                return -1;
            }
        }
#define stackunderflow(MINSIZE)				\
	if(stptr<MINSIZE){				\
	    rrd_set_error("RPN stack underflow");	\
	    return -1;					\
	}

        switch (rpnp[rpi].op) {
        case OP_NUMBER:
            rpnstack->s[++stptr] = rpnp[rpi].val;
            break;
        case OP_VARIABLE:
        case OP_PREV_OTHER:
            /* Sanity check: VDEFs shouldn't make it here */
            if (rpnp[rpi].ds_cnt == 0) {
                rrd_set_error("VDEF made it into rpn_calc... aborting");
                return -1;
            } else {
                /* make sure we pull the correct value from
                 * the *.data array. Adjust the pointer into
                 * the array acordingly. Advance the ptr one
                 * row in the rra (skip over non-relevant
                 * data sources)
                 */
                if (rpnp[rpi].op == OP_VARIABLE) {
                    rpnstack->s[++stptr] = *(rpnp[rpi].data);
                } else {
                    if ((output_idx) <= 0) {
                        rpnstack->s[++stptr] = DNAN;
                    } else {
                        rpnstack->s[++stptr] =
                            *(rpnp[rpi].data - rpnp[rpi].ds_cnt);
                    }

                }
                if (data_idx % rpnp[rpi].step == 0) {
                    rpnp[rpi].data += rpnp[rpi].ds_cnt;
                }
            }
            break;
        case OP_COUNT:
            rpnstack->s[++stptr] = (output_idx + 1);    /* Note: Counter starts at 1 */
            break;
        case OP_PREV:
            if ((output_idx) <= 0) {
                rpnstack->s[++stptr] = DNAN;
            } else {
                rpnstack->s[++stptr] = output[output_idx - 1];
            }
            break;
        case OP_UNKN:
            rpnstack->s[++stptr] = DNAN;
            break;
        case OP_INF:
            rpnstack->s[++stptr] = DINF;
            break;
        case OP_NEGINF:
            rpnstack->s[++stptr] = -DINF;
            break;
        case OP_NOW:
            rpnstack->s[++stptr] = (double) time(NULL);
            break;
        case OP_TIME:
            /* HACK: this relies on the data_idx being the time,
             ** which the within-function scope is unaware of */
            rpnstack->s[++stptr] = (double) data_idx;
            break;
        case OP_LTIME:
            rpnstack->s[++stptr] =
                (double) tzoffset(data_idx) + (double) data_idx;
            break;
        case OP_ADD:
            stackunderflow(1);
            rpnstack->s[stptr - 1] = rpnstack->s[stptr - 1]
                + rpnstack->s[stptr];
            stptr--;
            break;
        case OP_ADDNAN:
            stackunderflow(1);
            if (isnan(rpnstack->s[stptr - 1])) {
                rpnstack->s[stptr - 1] = rpnstack->s[stptr];
            } else if (isnan(rpnstack->s[stptr])) {
                /* NOOP */
                /* rpnstack->s[stptr - 1] = rpnstack->s[stptr - 1]; */
            } else {
                rpnstack->s[stptr - 1] = rpnstack->s[stptr - 1]
                    + rpnstack->s[stptr];
            }

            stptr--;
            break;
        case OP_SUB:
            stackunderflow(1);
            rpnstack->s[stptr - 1] = rpnstack->s[stptr - 1]
                - rpnstack->s[stptr];
            stptr--;
            break;
        case OP_MUL:
            stackunderflow(1);
            rpnstack->s[stptr - 1] = (rpnstack->s[stptr - 1])
                * (rpnstack->s[stptr]);
            stptr--;
            break;
        case OP_DIV:
            stackunderflow(1);
            rpnstack->s[stptr - 1] = rpnstack->s[stptr - 1]
                / rpnstack->s[stptr];
            stptr--;
            break;
        case OP_MOD:
            stackunderflow(1);
            rpnstack->s[stptr - 1] = fmod(rpnstack->s[stptr - 1]
                                          , rpnstack->s[stptr]);
            stptr--;
            break;
        case OP_SIN:
            stackunderflow(0);
            rpnstack->s[stptr] = sin(rpnstack->s[stptr]);
            break;
        case OP_ATAN:
            stackunderflow(0);
            rpnstack->s[stptr] = atan(rpnstack->s[stptr]);
            break;
        case OP_RAD2DEG:
            stackunderflow(0);
            rpnstack->s[stptr] = 57.29577951 * rpnstack->s[stptr];
            break;
        case OP_DEG2RAD:
            stackunderflow(0);
            rpnstack->s[stptr] = 0.0174532952 * rpnstack->s[stptr];
            break;
        case OP_ATAN2:
            stackunderflow(1);
            rpnstack->s[stptr - 1] = atan2(rpnstack->s[stptr - 1],
                                           rpnstack->s[stptr]);
            stptr--;
            break;
        case OP_COS:
            stackunderflow(0);
            rpnstack->s[stptr] = cos(rpnstack->s[stptr]);
            break;
        case OP_CEIL:
            stackunderflow(0);
            rpnstack->s[stptr] = ceil(rpnstack->s[stptr]);
            break;
        case OP_FLOOR:
            stackunderflow(0);
            rpnstack->s[stptr] = floor(rpnstack->s[stptr]);
            break;
        case OP_LOG:
            stackunderflow(0);
            rpnstack->s[stptr] = log(rpnstack->s[stptr]);
            break;
        case OP_DUP:
            stackunderflow(0);
            rpnstack->s[stptr + 1] = rpnstack->s[stptr];
            stptr++;
            break;
        case OP_POP:
            stackunderflow(0);
            stptr--;
            break;
        case OP_EXC:
            stackunderflow(1);
            {
                double    dummy;

                dummy = rpnstack->s[stptr];
                rpnstack->s[stptr] = rpnstack->s[stptr - 1];
                rpnstack->s[stptr - 1] = dummy;
            }
            break;
        case OP_EXP:
            stackunderflow(0);
            rpnstack->s[stptr] = exp(rpnstack->s[stptr]);
            break;
        case OP_LT:
            stackunderflow(1);
            if (isnan(rpnstack->s[stptr - 1]));
            else if (isnan(rpnstack->s[stptr]))
                rpnstack->s[stptr - 1] = rpnstack->s[stptr];
            else
                rpnstack->s[stptr - 1] = rpnstack->s[stptr - 1] <
                    rpnstack->s[stptr] ? 1.0 : 0.0;
            stptr--;
            break;
        case OP_LE:
            stackunderflow(1);
            if (isnan(rpnstack->s[stptr - 1]));
            else if (isnan(rpnstack->s[stptr]))
                rpnstack->s[stptr - 1] = rpnstack->s[stptr];
            else
                rpnstack->s[stptr - 1] = rpnstack->s[stptr - 1] <=
                    rpnstack->s[stptr] ? 1.0 : 0.0;
            stptr--;
            break;
        case OP_GT:
            stackunderflow(1);
            if (isnan(rpnstack->s[stptr - 1]));
            else if (isnan(rpnstack->s[stptr]))
                rpnstack->s[stptr - 1] = rpnstack->s[stptr];
            else
                rpnstack->s[stptr - 1] = rpnstack->s[stptr - 1] >
                    rpnstack->s[stptr] ? 1.0 : 0.0;
            stptr--;
            break;
        case OP_GE:
            stackunderflow(1);
            if (isnan(rpnstack->s[stptr - 1]));
            else if (isnan(rpnstack->s[stptr]))
                rpnstack->s[stptr - 1] = rpnstack->s[stptr];
            else
                rpnstack->s[stptr - 1] = rpnstack->s[stptr - 1] >=
                    rpnstack->s[stptr] ? 1.0 : 0.0;
            stptr--;
            break;
        case OP_NE:
            stackunderflow(1);
            if (isnan(rpnstack->s[stptr - 1]));
            else if (isnan(rpnstack->s[stptr]))
                rpnstack->s[stptr - 1] = rpnstack->s[stptr];
            else
                rpnstack->s[stptr - 1] = rpnstack->s[stptr - 1] ==
                    rpnstack->s[stptr] ? 0.0 : 1.0;
            stptr--;
            break;
        case OP_EQ:
            stackunderflow(1);
            if (isnan(rpnstack->s[stptr - 1]));
            else if (isnan(rpnstack->s[stptr]))
                rpnstack->s[stptr - 1] = rpnstack->s[stptr];
            else
                rpnstack->s[stptr - 1] = rpnstack->s[stptr - 1] ==
                    rpnstack->s[stptr] ? 1.0 : 0.0;
            stptr--;
            break;
        case OP_IF:
            stackunderflow(2);
            rpnstack->s[stptr - 2] = (isnan(rpnstack->s[stptr - 2])
                                      || rpnstack->s[stptr - 2] ==
                                      0.0) ? rpnstack->s[stptr] : rpnstack->
                s[stptr - 1];
            stptr--;
            stptr--;
            break;
        case OP_MIN:
            stackunderflow(1);
            if (isnan(rpnstack->s[stptr - 1]));
            else if (isnan(rpnstack->s[stptr]))
                rpnstack->s[stptr - 1] = rpnstack->s[stptr];
            else if (rpnstack->s[stptr - 1] > rpnstack->s[stptr])
                rpnstack->s[stptr - 1] = rpnstack->s[stptr];
            stptr--;
            break;
        case OP_MINNAN:
            stackunderflow(1);
            if (isnan(rpnstack->s[stptr - 1]))
                rpnstack->s[stptr - 1] = rpnstack->s[stptr];
            else if (isnan(rpnstack->s[stptr]));
            else if (rpnstack->s[stptr - 1] > rpnstack->s[stptr])
                rpnstack->s[stptr - 1] = rpnstack->s[stptr];
            stptr--;
            break;
        case OP_MAX:
            stackunderflow(1);
            if (isnan(rpnstack->s[stptr - 1]));
            else if (isnan(rpnstack->s[stptr]))
                rpnstack->s[stptr - 1] = rpnstack->s[stptr];
            else if (rpnstack->s[stptr - 1] < rpnstack->s[stptr])
                rpnstack->s[stptr - 1] = rpnstack->s[stptr];
            stptr--;
            break;
        case OP_MAXNAN:
            stackunderflow(1);
            if (isnan(rpnstack->s[stptr - 1]))
                rpnstack->s[stptr - 1] = rpnstack->s[stptr];
            else if (isnan(rpnstack->s[stptr]));
            else if (rpnstack->s[stptr - 1] < rpnstack->s[stptr])
                rpnstack->s[stptr - 1] = rpnstack->s[stptr];
            stptr--;
            break;
        case OP_LIMIT:
            stackunderflow(2);
            if (isnan(rpnstack->s[stptr - 2]));
            else if (isnan(rpnstack->s[stptr - 1]))
                rpnstack->s[stptr - 2] = rpnstack->s[stptr - 1];
            else if (isnan(rpnstack->s[stptr]))
                rpnstack->s[stptr - 2] = rpnstack->s[stptr];
            else if (rpnstack->s[stptr - 2] < rpnstack->s[stptr - 1])
                rpnstack->s[stptr - 2] = DNAN;
            else if (rpnstack->s[stptr - 2] > rpnstack->s[stptr])
                rpnstack->s[stptr - 2] = DNAN;
            stptr -= 2;
            break;
        case OP_UN:
            stackunderflow(0);
            rpnstack->s[stptr] = isnan(rpnstack->s[stptr]) ? 1.0 : 0.0;
            break;
        case OP_ISINF:
            stackunderflow(0);
            rpnstack->s[stptr] = isinf(rpnstack->s[stptr]) ? 1.0 : 0.0;
            break;
        case OP_SQRT:
            stackunderflow(0);
            rpnstack->s[stptr] = sqrt(rpnstack->s[stptr]);
            break;
        case OP_SORT:
            stackunderflow(0);
            {
                int       spn = (int) rpnstack->s[stptr--];

                stackunderflow(spn - 1);
                qsort(rpnstack->s + stptr - spn + 1, spn, sizeof(double),
                      rpn_compare_double);
            }
            break;
        case OP_REV:
            stackunderflow(0);
            {
                int       spn = (int) rpnstack->s[stptr--];
                double   *p, *q;

                stackunderflow(spn - 1);

                p = rpnstack->s + stptr - spn + 1;
                q = rpnstack->s + stptr;
                while (p < q) {
                    double    x = *q;

                    *q-- = *p;
                    *p++ = x;
                }
            }
            break;
        case OP_PREDICT:
        case OP_PREDICTSIGMA:
            stackunderflow(2);
	    {
		/* the local averaging window (similar to trend, but better here, as we get better statistics thru numbers)*/
		int   locstepsize = rpnstack->s[--stptr];
		/* the number of shifts and range-checking*/
		int     shifts = rpnstack->s[--stptr];
                stackunderflow(shifts);
		// handle negative shifts special
		if (shifts<0) {
		    stptr--;
		} else {
		    stptr-=shifts;
		}
		/* the real calculation */
		double val=DNAN;
		/* the info on the datasource */
		time_t  dsstep = (time_t) rpnp[rpi - 1].step;
		int    dscount = rpnp[rpi - 1].ds_cnt;
		int   locstep = (int)ceil((float)locstepsize/(float)dsstep);

		/* the sums */
                double    sum = 0;
		double    sum2 = 0;
                int       count = 0;
		/* now loop for each position */
		int doshifts=shifts;
		if (shifts<0) { doshifts=-shifts; }
		for(int loop=0;loop<doshifts;loop++) {
		    /* calculate shift step */
		    int shiftstep=1;
		    if (shifts<0) {
			shiftstep = loop*rpnstack->s[stptr];
		    } else { 
			shiftstep = rpnstack->s[stptr+loop]; 
		    }
		    if(shiftstep <0) {
			rrd_set_error("negative shift step not allowed: %i",shiftstep);
			return -1;
		    }
		    shiftstep=(int)ceil((float)shiftstep/(float)dsstep);
		    /* loop all local shifts */
		    for(int i=0;i<=locstep;i++) {
			/* now calculate offset into data-array - relative to output_idx*/
			int offset=shiftstep+i;
			/* and process if we have index 0 of above */
			if ((offset>=0)&&(offset<output_idx)) {
			    /* get the value */
			    val =rpnp[rpi - 1].data[-dscount * offset];
			    /* and handle the non NAN case only*/
			    if (! isnan(val)) {
				sum+=val;
				sum2+=val*val;
				count++;
			    }
			}
		    }
		}
		/* do the final calculations */
		val=DNAN;
		if (rpnp[rpi].op == OP_PREDICT) {  /* the average */
		    if (count>0) {
			val = sum/(double)count;
		    } 
		} else {
		    if (count>1) { /* the sigma case */
			val=count*sum2-sum*sum;
			if (val<0) {
			    val=DNAN;
			} else {
			    val=sqrt(val/((float)count*((float)count-1.0)));
			}
		    }
		}
		rpnstack->s[stptr] = val;
	    }
            break;
        case OP_TREND:
        case OP_TRENDNAN:
            stackunderflow(1);
            if ((rpi < 2) || (rpnp[rpi - 2].op != OP_VARIABLE)) {
                rrd_set_error("malformed trend arguments");
                return -1;
            } else {
                time_t    dur = (time_t) rpnstack->s[stptr];
                time_t    step = (time_t) rpnp[rpi - 2].step;

                if (output_idx + 1 >= (int) ceil((float) dur / (float) step)) {
                    int       ignorenan = (rpnp[rpi].op == OP_TREND);
                    double    accum = 0.0;
                    int       i = -1; /* pick the current entries, not the next one
                                         as the data pointer has already been forwarded
                                         when the OP_VARIABLE was processed */
                    int       count = 0;

                    do {
                        double    val =
                            rpnp[rpi - 2].data[rpnp[rpi - 2].ds_cnt * i--];
                        if (ignorenan || !isnan(val)) {
                            accum += val;
                            ++count;
                        }

                        dur -= step;
                    } while (dur > 0);

                    rpnstack->s[--stptr] =
                        (count == 0) ? DNAN : (accum / count);
                } else
                    rpnstack->s[--stptr] = DNAN;
            }
            break;
        case OP_AVG:
            stackunderflow(0);
            {
                int       i = (int) rpnstack->s[stptr--];
                double    sum = 0;
                int       count = 0;

                stackunderflow(i - 1);
                while (i > 0) {
                    double    val = rpnstack->s[stptr--];

                    i--;
                    if (isnan(val)) {
                        continue;
                    }
                    count++;
                    sum += val;
                }
                /* now push the result back on stack */
                if (count > 0) {
                    rpnstack->s[++stptr] = sum / count;
                } else {
                    rpnstack->s[++stptr] = DNAN;
                }
            }
            break;
        case OP_ABS:
            stackunderflow(0);
            rpnstack->s[stptr] = fabs(rpnstack->s[stptr]);
            break;
        case OP_END:
            break;
        }
#undef stackunderflow
    }
    if (stptr != 0) {
        rrd_set_error("RPN final stack size != 1");
        return -1;
    }

    output[output_idx] = rpnstack->s[0];
    return 0;
}

/* figure out what the local timezone offset for any point in
   time was. Return it in seconds */
int tzoffset(
    time_t now)
{
    int       gm_sec, gm_min, gm_hour, gm_yday, gm_year,
        l_sec, l_min, l_hour, l_yday, l_year;
    struct tm t;
    int       off;

    gmtime_r(&now, &t);
    gm_sec = t.tm_sec;
    gm_min = t.tm_min;
    gm_hour = t.tm_hour;
    gm_yday = t.tm_yday;
    gm_year = t.tm_year;
    localtime_r(&now, &t);
    l_sec = t.tm_sec;
    l_min = t.tm_min;
    l_hour = t.tm_hour;
    l_yday = t.tm_yday;
    l_year = t.tm_year;
    off =
        (l_sec - gm_sec) + (l_min - gm_min) * 60 + (l_hour - gm_hour) * 3600;
    if (l_yday > gm_yday || l_year > gm_year) {
        off += 24 * 3600;
    } else if (l_yday < gm_yday || l_year < gm_year) {
        off -= 24 * 3600;
    }
    return off;
}
