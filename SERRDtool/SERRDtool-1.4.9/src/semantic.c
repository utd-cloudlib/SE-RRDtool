#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "semantic.h"

#define MAX_FILE_NAME_LENGTH 4096
#define MAX_DS_NAME_LENGTH 20

char** redirect(int argc, char** argv, int optind) {
    char fullPath[MAX_FILE_NAME_LENGTH];
    char fileName[MAX_FILE_NAME_LENGTH];
    char buff[MAX_FILE_NAME_LENGTH];
    char DSName[MAX_DS_NAME_LENGTH];
    char **result = (char**)malloc(sizeof(char*) * argc);

    int ind, loc = -1, i, loc_DS = 0, j, mem_size = 0;
    int offset[argc];
    char c;

    strcpy(fullPath, argv[optind]);
    // get ds name
    for(ind = 0; ind < argc; ++ind) {
	if(strncmp(argv[ind], "DS:", 3) == 0) {
	    for(i = 0; i < MAX_DS_NAME_LENGTH; ++i) {
		c = argv[ind][3+i];
		if(c == ':') break;
		DSName[i] = c;
	    }
	    DSName[i] = '\0';
	    loc_DS = 3 + i;
	    break;
	}
    }
    //printf("path: %s - ds: %s\n", fullPath, DSName);

    // get file name
    for(ind = 0; ind < MAX_FILE_NAME_LENGTH; ++ind) {
        c = fullPath[i];
	if(c == '\0') break;
	if(c == '/') {
	    loc = ind;
	}
    }

    if(loc >= 0) {
	for(ind = 0; ind < MAX_FILE_NAME_LENGTH; ++ind) {
	    c = fullPath[loc+ind+1];
	    if(c == '\0') break;
	    fileName[ind] = c;
        }
        fileName[ind] = '\0';
    }
    else {
	strcpy(fileName, fullPath);
    }
    //printf("file: %s - ds: %s\n", fileName, DSName);

    // get file name and ds name from web service
    if(!strcmp(argv[optind - 1], "create")) { // optind - 1 is the index of function
        
    }
    else {
        
    }

    // mock names
    strcpy(fileName, "testname.rrd");
    strcpy(DSName, "metric");

    // reconstruct the new full file path
    for(ind = 0; ind < MAX_FILE_NAME_LENGTH; ++ind) {
	c = fileName[ind];
	if(c == '\0') break;
	fullPath[loc+ind+1] = c;
    }
    fullPath[loc+ind+1] = '\0';

    // reconstruct arguments
    for(ind = 0; ind < argc; ++ind) {
	if(ind == optind) { // path
	    offset[ind] = strlen(fullPath) + 1;
	}
	else if(strncmp(argv[ind], "DS:", 3) == 0) { // DS
	    offset[ind] = 3 + strlen(DSName) + strlen(argv[ind]) - loc_DS + 1;
	}
	else {
	    offset[ind] = strlen(argv[ind]) + 1;
	}
	mem_size += offset[ind];
    }

    result[0] = (char*)malloc(sizeof(char) * mem_size);
    for(ind = 1; ind < argc; ++ind) {
	result[ind] = result[ind - 1] + offset[ind - 1];
    }

    for(ind = 0; ind < argc; ++ind) {
	if(ind == optind) {
	    strcpy(result[ind], fullPath);
	}
	else if(strncmp(argv[ind], "DS:", 3) == 0) {
	    strcpy(buff, argv[ind]);
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
	    strcpy(result[ind], argv[ind]);
	}
    }

    return result;
}

int main(int argc, char **argv) {
    int i;
    char** res = redirect(argc, argv, 2);
    for(i = 0; i < argc; ++i) {
	printf("%s\n", res[i]);
    }
}
