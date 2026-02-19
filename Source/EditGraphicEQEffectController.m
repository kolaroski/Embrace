// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import "EditGraphicEQEffectController.h"
#import "Effect.h"
#import "EffectAdditions.h"
#import "EffectType.h"
#import "GraphicEQView.h"

#import <AudioUnit/AUCocoaUIView.h>

@interface EditGraphicEQEffectController ()

@property (nonatomic, weak) IBOutlet NSVisualEffectView *backgroundView;
@property (nonatomic, weak) IBOutlet GraphicEQView *graphicEQView;
@property (nonatomic, weak) IBOutlet NSImageView *infoIcon;

@end


@implementation EditGraphicEQEffectController

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (NSString *) windowNibName
{
    return @"EditGraphicEQEffectWindow";
}


- (void) windowDidLoad
{
    [super windowDidLoad];

    [_graphicEQView setAudioUnit:[[self effect] audioUnit]];
   
    CGSize contentSize = CGSizeMake(
        [_graphicEQView numberOfBands] == 10 ? 362 : 765,
        215
    );

    NSWindow *window = [self window];
    [window setContentMinSize:contentSize];
    [window setContentMaxSize:contentSize];
    [window setMovableByWindowBackground:YES];
    [window setTitleVisibility:NSWindowTitleHidden];
    [window setTitlebarAppearsTransparent:YES];

    CGRect rect = [window contentRectForFrameRect:[window frame]];
    rect.size = contentSize;
    rect = [window frameRectForContentRect:rect];

    [window setFrame:rect display:YES animate:NO];
    
    // Adjust subviews (we can't do this in Interface Builder as the NSVisualEffectView
    // obscures the toolbar
    //
    [[self backgroundView] setFrame:[[window contentView] bounds]];

    CGRect eqViewFrame = [[self backgroundView] bounds];
    eqViewFrame.size.height -= 34;
    [[self graphicEQView] setFrame:eqViewFrame];
    
    // Information icon
    NSClickGestureRecognizer *clickGesture = [[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(showHelpText:)];
    [self.infoIcon addGestureRecognizer:clickGesture];
}

- (NSURL *) _urlForPresetSlot:(NSString *)slotName
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *appSupport = [fm URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    NSURL *folder = [appSupport URLByAppendingPathComponent:@"Embrace/Presets"];
    
    if (![fm fileExistsAtPath:[folder path]]) {
        [fm createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return [[folder URLByAppendingPathComponent:slotName] URLByAppendingPathExtension:@"aupreset"];
}

- (void) _handlePresetSlot:(NSString *)slotName sender:(id)sender
{
    NSURL *url = [self _urlForPresetSlot:slotName];
    NSEvent *event = [NSApp currentEvent];
    
    // Check if "Option" key is held down
    BOOL isSaving = ([event modifierFlags] & NSEventModifierFlagOption) != 0;
    
    if (isSaving) {
        // --- SAVE ---
        [[self effect] saveAudioPresetAtFileURL:url];
        NSBeep(); // distinct sound for save
        NSLog(@"Saved preset to slot %@", slotName);
        
        NSButton *button = (NSButton *)sender;
                    
        NSString *originalTitle = button.title;
        
        button.title = @"Saved!";
        
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.15;
            button.animator.alphaValue = 0.5;
        } completionHandler:^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.duration = 0.15;
                button.animator.alphaValue = 1.0;
            }];
        }];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // Make sure we update the UI on the main thread
            button.title = originalTitle;
        });
        
    } else {
        // --- LOAD ---
        if ([[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
            [[self effect] loadAudioPresetAtFileURL:url];
            [self reloadData];
            NSLog(@"Loaded preset from slot %@", slotName);
        } else {
            NSBeep(); // Error sound if slot is empty
            NSLog(@"Slot %@ is empty", slotName);
        }
    }
}



- (void) reloadData
{
    [_graphicEQView reloadData];
}

- (void)showHelpText:(NSGestureRecognizer *)gesture
{
    // 1. Remember the original icon so we can restore it later
    NSImage *originalImage = self.infoIcon.image;
    
    // 2. Create the new "smile" image using SF Symbols (macOS 11+)
    NSImage *smileImage = [NSImage imageWithSystemSymbolName:@"face.smiling" accessibilityDescription:nil];
    
    // 3. Animate the swap to the smile instantly
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.15;
        self.infoIcon.animator.image = smileImage;
    }];
    
    // 4. Set up your alert
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Saving Presets";
    alert.informativeText = @"Hold the ⌥ (Option) key and click a preset slot to save your current settings to that slot.";
    [alert setAlertStyle:NSAlertStyleInformational];
    [alert addButtonWithTitle:@"Got it!"];
    
    // 5. Show the alert (This pauses the code here until the user clicks "Got it!")
    [alert runModal];
    
    // 6. The user closed the alert! Animate the icon fading back to normal.
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.2;
        self.infoIcon.animator.image = originalImage;
    }];
}

#pragma mark - IBActions

- (IBAction) flatten:(id)sender
{
    [_graphicEQView flatten];
}

- (IBAction) togglePresetPre:(id)sender { [self _handlePresetSlot:@"Pre" sender:sender]; }
- (IBAction) togglePresetGolden:(id)sender { [self _handlePresetSlot:@"Golden" sender:sender]; }
- (IBAction) togglePresetPost:(id)sender { [self _handlePresetSlot:@"Post" sender:sender]; }
- (IBAction) togglePresetCortina:(id)sender { [self _handlePresetSlot:@"Cortina" sender:sender]; }

@end
