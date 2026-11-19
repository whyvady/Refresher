#import <UIKit/UIKit.h>

@interface RFPickerController : UIViewController

+ (void)presentWithTitle:(NSString *)title
                selected:(NSString *)selected
             defaultIcon:(UIImage *)defaultIcon
                ownNames:(NSArray *)ownNames
                  anchor:(CGRect (^)(void))anchor
              completion:(void (^)(NSString *name))completion;

@end
