#include <dirent.h>
#include <errno.h>
#include <fstream>
#include <iostream>
#include <stdio.h>
#include <signal.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

#include <INIReader.h>

#define ASK_PASSWD_DIR "/run/systemd/ask-password/"

int get_passwd(std::string &passwd) {
  const char* cred_dir = std::getenv("CREDENTIALS_DIRECTORY");
  if(cred_dir) {
    const std::string fname = std::string(cred_dir) + "/" + "@@MENDER/LUKS_SYSTEMD_INITRD_CREDENTIALS_VAR@@";
    std::ifstream fs(fname);
    if(fs.is_open()) {
      passwd = std::string(std::istreambuf_iterator<char>(fs), std::istreambuf_iterator<char>());
      while (!passwd.empty() && passwd.back() == '\n') {
        passwd.pop_back();
      }
      fs.close();
      return 0;
    } else {
      fprintf(stderr, "failed to open %s: %s\n", fname.c_str(), strerror(errno));
    }
  } else {
    fprintf(stderr, "missing CREDENTIALS_DIRECTORY: %s\n", strerror(errno));
  }
  passwd.clear();
  return -1;
}

int write_passwd(std::string socket, std::string passwd) {
  const std::string cmd_str = "/lib/systemd/systemd-reply-password 1 " + socket;
  FILE *cmd = popen(cmd_str.c_str(), "w");
  if (cmd) {
    const auto fputs_rtn = fputs(passwd.c_str(), cmd);
    return ((pclose(cmd) == 0) && (fputs_rtn != EOF)) ? 0 : -1;
  }
  return -1;
}

int main(int argc, char **argv) {
  DIR *dir = opendir(ASK_PASSWD_DIR);
  if (dir) {
    struct dirent *de;
    while ((de = readdir(dir)) != NULL) {
      if (de->d_type != DT_REG)                continue;
      if (strncmp(de->d_name, "ask.", 4) != 0) continue;

      const INIReader reader(std::string(ASK_PASSWD_DIR) + std::string(de->d_name));
      if (!reader.ParseError()) {
        const std::string id = reader.Get("Ask", "Id", "");
        if (id.empty()) {
          fprintf(stderr, "error parsing [Ask]Id: %s\n", strerror(errno));
          continue;
        }
        if (id.compare(0, 10, "cryptsetup") != 0) {
          fprintf(stderr, "Id (%s) != cryptsetup*, skipping this Id\n", id.c_str());
          continue;
        }

        const int pid = reader.GetInteger("Ask", "PID", -1);
        if (pid == -1) {
          fprintf(stderr, "error parsing [Ask]PID: %s\n", strerror(errno));
          continue;
        }
        if (kill(pid, 0) != 0) {
          if (errno == ESRCH) {
            fprintf(stderr, "error on kill(%d,0): %s\n", pid, strerror(errno));
            continue;
          }
        }

        const std::string socket = reader.Get("Ask", "Socket", "");
        if (socket.empty()) {
          fprintf(stderr, "error parsing [Ask]Socket: %s\n", strerror(errno));
          continue;
        }

        std::string passwd;
        if (get_passwd(passwd) == 0) {
          if (write_passwd(socket, passwd) == 0) {
            ; // success
          }
        }
      } // if(INIReader)
    }   // while
  }     // if(dir)
  closedir(dir);
  exit(0);
}
