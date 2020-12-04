#include <stddef.h>
#include <unistd.h>
#include <string.h>
#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <dirent.h>
#include <sys/types.h>
#include <limits.h>

#include <sys/socket.h>
#include <sys/un.h>
#include <signal.h>

#include <inih/INIReader.h>

#define ASK_PASSWD_DIR "/run/systemd/ask-password/"
#define GET_PASSWD_CMD "@@MENDER/LUKS_PASSWORD_AGENT_CMD@@"

int main( int argc, char **argv )
{
  DIR *d = opendir(ASK_PASSWD_DIR);
  struct dirent *de;
  char * test = NULL;

  if( !d ) {
    fprintf(stderr, "error opening directory (%s): %s\n", ASK_PASSWD_DIR, strerror(errno));
    exit(-1);
  }

  while( (de = readdir(d)) != NULL) {
    if( de->d_type != DT_REG ) {
      continue;
    }

    if( de->d_name[0] == '.' ) continue;                      //hidden file
    else if( (test = strrchr(de->d_name, '~')) != NULL ) {    //backup ~
      if( strlen(test) <= 1 ) continue;
    } else if( (test = strrchr(de->d_name, '.')) != NULL ) {  //check for common tmp file suffix
      if( ( strncmp(test + 1, "bak", 3) == 0 ) ||
          ( strncmp(test + 1, "swp", 3) == 0 ) ||
          ( strncmp(test + 1, "old", 3) == 0 ) ||
          ( strncmp(test + 1, "new", 3) == 0 )  ) continue;
    } else if( strncmp(de->d_name, "ask.", 4) != 0) continue; //needs ask.* prefix

    //parse INI file
    std::string iniFilename = std::string(ASK_PASSWD_DIR) + std::string(de->d_name);
    INIReader reader( iniFilename );

    if( reader.ParseError() < 0 ) {
      fprintf(stderr, "error parsing INI (%s): %s\n", iniFilename.c_str(), strerror(errno));
      continue;
    }
    fprintf(stderr, "INI (%s)\n", iniFilename.c_str());

    //parse Id=
    {
      std::string id = reader.Get("Ask", "Id", "");

      if( ! id.empty() ) {
        if( id.compare(0,10,"cryptsetup") != 0 ) {
          fprintf(stderr, "ID (%s) != cryptsetup*, skipping this ID\n", id.c_str());
          continue;
        }
      } else {
        fprintf(stderr, "error parsing ID (%s): %s\n", id.c_str(), strerror(errno));
        continue;
      }
      fprintf(stderr, "ID (%s)\n", id.c_str());
    }

    //parse PID=
    {
      int pid = reader.GetInteger("Ask", "PID", 0);

      if( pid != 0 ) {
        if( kill(pid, 0) != 0 ) {
          if(errno == ESRCH) {
            fprintf(stderr, "error on kill(%d,0), skipping this PID: %s\n", pid, strerror(errno));
            continue;
          }
        }
      } else {
        fprintf(stderr, "error parsing PID (%d): %s\n", pid, strerror(errno));
        continue;
      }
      fprintf(stderr, "PID (%d)\n", pid);
    }

    //parse Socket=
    {
      std::string socket = reader.Get("Ask", "Socket", "");

      if( ! socket.empty() ) {
        int rc = 0;

        FILE *cmd = NULL;
        char cmd_str[2048];
        char key_str[2048];

        sprintf(cmd_str, GET_PASSWD_CMD);
        fprintf(stderr, "Socket (%s)\n", socket.c_str());
        fprintf(stderr, "CMD    (%s)\n", cmd_str);

        cmd = popen(cmd_str, "r");
        if( !cmd ) {
          fprintf(stderr, "error calling %s: %s\n", cmd_str, strerror(errno));
          continue;
        }

        if( fgets(key_str, sizeof(key_str), cmd) == NULL ) {
          fprintf(stderr, "error reading passphrase: %s\n", strerror(errno));
          continue;
        }

        if( (rc = pclose(cmd)) != 0 ) {
          fprintf(stderr, "%s closed w/ rc=%d: %s\n", cmd_str, rc, strerror(errno));
        }

        sprintf(cmd_str, "/lib/systemd/systemd-reply-password 1 %s", socket.c_str());
        fprintf(stderr, "CMD    (%s)\n", cmd_str);

        cmd = popen(cmd_str, "w");
        if( !cmd ) {
          fprintf(stderr, "error calling %s: %s\n", cmd_str, strerror(errno));
          continue;
        }

        if( (rc = fputs(key_str, cmd)) == EOF ) {
          fprintf(stderr, "error writing passphrase to socket: %s\n", strerror(errno));
          continue;
        }
        if( (rc = pclose(cmd)) != 0 ) {
          fprintf(stderr, "%s closed w/ rc=%d: %s\n", cmd_str, rc, strerror(errno));
        }

      } else {
          fprintf(stderr, "error parsing socket(%s): %s\n", socket.c_str(), strerror(errno));
          continue;
      }
    }

    sleep(5);
  }

  return 0;
}
