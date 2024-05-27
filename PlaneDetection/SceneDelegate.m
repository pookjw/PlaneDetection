//
//  SceneDelegate.m
//  PlaneDetection
//
//  Created by Jinwoo Kim on 5/27/24.
//

#import "SceneDelegate.h"
#import "CollectionViewController.h"

@interface SceneDelegate ()
@end

@implementation SceneDelegate

- (void)dealloc {
    [_window release];
    [super dealloc];
}

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    CollectionViewController *collectionViewController = [CollectionViewController new];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:collectionViewController];
    [collectionViewController release];
    window.rootViewController = navigationController;
    [navigationController release];
    self.window = window;
    [window makeKeyAndVisible];
    [window release];
}

@end
