// Read-only probe for the throwaway lock-screen overlap experiment.
// It never starts the saver, locks the Mac, changes settings or captures images.
// A candidate overlap still needs a screenshot and saver-instance identification.
#include <notify.h>
#include <libproc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

int main(int argc, char **argv) {
    int seconds = argc > 1 ? atoi(argv[1]) : 30;
    if (seconds < 1 || seconds > 120) return 2;
    int token;
    unsigned status = notify_register_check("com.apple.sessionagent.screenLockUIIsShowing", &token);
    if (status != NOTIFY_STATUS_OK) { fprintf(stderr, "notify registration failed: %u\n", status); return 2; }
    int observed = 0;
    for (int tick = 0; tick < seconds * 4; tick++) {
        uint64_t shown = 0;
        status = notify_get_state(token, &shown);
        if (status != NOTIFY_STATUS_OK) { fprintf(stderr, "notify read failed: %u\n", status); notify_cancel(token); return 2; }
        pid_t pids[8192];
        int bytes = proc_listpids(PROC_ALL_PIDS, 0, pids, sizeof(pids));
        if (bytes <= 0) { fprintf(stderr, "process enumeration failed\n"); notify_cancel(token); return 2; }
        char matches[1024] = "";
        int count = 0;
        for (int i = 0; i < bytes / (int)sizeof(pid_t); i++) {
            char path[PROC_PIDPATHINFO_MAXSIZE];
            if (proc_pidpath(pids[i], path, sizeof(path)) <= 0) continue;
            const char *name = strrchr(path, '/');
            if (!name || strcmp(name + 1, "AppexSaverMinimalExtension")) continue;
            char id[32]; snprintf(id, sizeof(id), "%s%d", count ? "," : "", pids[i]);
            strlcat(matches, id, sizeof(matches)); count++;
        }
        struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts);
        printf("epoch=%lld.%03ld lock_ui=%llu extension_pids=%s candidate_overlap=%d\n",
               (long long)ts.tv_sec, ts.tv_nsec / 1000000,
               (unsigned long long)shown, count ? matches : "none", shown == 1 && count > 0);
        fflush(stdout);
        if (shown == 1 && count > 0) observed = 1;
        usleep(250000);
    }
    notify_cancel(token);
    puts(observed ? "CANDIDATE: verify same saver instance and visible overlap in screenshots"
                  : "NO_OVERLAP_OBSERVED");
    return observed ? 0 : 1;
}
