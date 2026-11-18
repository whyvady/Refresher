#import "root-controller.h"
#import <spawn.h>

extern char **environ;

@implementation RFRootListController

- (NSString *)plistName {
    return @"root";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Respring"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(respring)];
}

- (void)respring {
    pid_t pid;
    char *const arguments[] = {"killall", "-9", "SpringBoard", NULL};
    posix_spawnp(&pid, "killall", NULL, NULL, arguments, environ);
}

@end
