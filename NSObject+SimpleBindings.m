//
//  NSObject+SimpleBindings.m
//  Fluxus
//
//  Created by Marcel Ruegenberg on 21.03.11.
//  Copyright 2011 Dustlab. All rights reserved.
//

#import "NSObject+SimpleBindings.h"
#import <objc/runtime.h>
#import "Util.h"


@interface NSArray (BindingsHelpers)

// array with all objects but the last; if the original array was empty, returns the original array
- (NSArray *)initArray;

@end

@implementation NSArray (ArrayFP)

- (NSArray *)initialArray {
    NSUInteger c = [self count];
    if(c == 0) return self;
    else return [self subarrayWithRange:NSMakeRange(0, c - 1)];
}

@end



@interface ObjectBinding : NSObject

@property (assign) NSObject *obj1;
@property (copy) NSString *keyPath1;
@property (assign) NSObject *obj2;
@property (copy) NSString *keyPath2;

- (id)initWithKeyPath:(NSString *)keyPath1 ofObj:(NSObject *)obj1 keyPath:(NSString *)keyPath2 ofObj:(NSObject *)obj2;

- (void)deactivateBinding;

- (BOOL)containsObject:(NSObject *)object;

- (NSObject *)otherObject:(NSObject *)obj;

@property BOOL bindingActive;

@property BOOL isKeyPath1;
@property BOOL isKeyPath2;

@end

@implementation ObjectBinding
@synthesize obj1, keyPath1, obj2, keyPath2, bindingActive;
@synthesize isKeyPath1, isKeyPath2;

- (id)initWithKeyPath:(NSString *)keyPath1_ ofObj:(NSObject *)obj1_ keyPath:(NSString *)keyPath2_ ofObj:(NSObject *)obj2_ {
    if((self = [super init])) {
        self.obj1 = obj1_; self.keyPath1 = keyPath1_;
        self.obj2 = obj2_; self.keyPath2 = keyPath2_;
        
        NSString *key1 = [[[self.keyPath1 componentsSeparatedByString:@"."] initialArray] componentsJoinedByString:@"."];
        if(key1 == nil || [key1 isEqualToString:@""]) key1 = self.keyPath1;
        self.isKeyPath1 = [self.obj1 valueForKeyPath:key1] != nil;
        NSString *key2 = [[[self.keyPath2 componentsSeparatedByString:@"."] initialArray] componentsJoinedByString:@"."];
        if(key2 == nil || [key2 isEqualToString:@""]) key2 = self.keyPath2;
        self.isKeyPath2 = [self.obj2 valueForKeyPath:key2] != nil;
        
        // only set key paths if that makes sense.
        // key paths only make sense if an object for the key path without the last component exists
        if(self.isKeyPath1) {
            if(self.isKeyPath2)
                [self.obj1 setValue:[self.obj2 valueForKeyPath:self.keyPath2] forKeyPath:self.keyPath1];
            else
                [self.obj1 setValue:[self.obj2 valueForKey:self.keyPath2] forKeyPath:self.keyPath1];
        }
        else {
            if(self.isKeyPath2)
                [self.obj1 setValue:[self.obj2 valueForKeyPath:self.keyPath2] forKey:self.keyPath1];
            else
                [self.obj1 setValue:[self.obj2 valueForKey:self.keyPath2] forKey:self.keyPath1];
        }
        [self.obj1 addObserver:self forKeyPath:self.keyPath1 options:0 context:NULL];
        [self.obj2 addObserver:self forKeyPath:self.keyPath2 options:0 context:NULL];
		self.bindingActive = YES;
    }
    return self;
}

- (void)deactivateBinding {
    [self.obj1 removeObserver:self forKeyPath:self.keyPath1];
    [self.obj2 removeObserver:self forKeyPath:self.keyPath2];
	self.bindingActive = NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    // otherobject is the object which needs to be changed in response to this method call
    NSObject *otherObject; NSString *otherKeyPath; BOOL isKeyPath, otherIsKeyPath;
    
    if(object == self.obj1 && [keyPath isEqualToString:self.keyPath1]) { // the notification is from observing obj1
        otherObject = self.obj2; otherKeyPath = self.keyPath2; isKeyPath = self.isKeyPath1; otherIsKeyPath = self.isKeyPath2; 
    }
    else if(object == self.obj2 && [keyPath isEqualToString:self.keyPath2]) { // notification is from observing obj2
        otherObject = self.obj1; otherKeyPath = self.keyPath1; isKeyPath = self.isKeyPath2; otherIsKeyPath = self.isKeyPath1; 
    }
    else {
        NSAssert2(NO, @"Binding received notification for object (%@) it shouldn't observe with keypath %@.", object, keyPath);
        return;
    } 
    
    id val = isKeyPath ? [object valueForKeyPath:keyPath] : [object valueForKey:keyPath];
    
    // TODO: declutter
    if(isKeyPath) {
        if(otherIsKeyPath) {
            if((! [[object valueForKeyPath:keyPath] isEqual:[otherObject valueForKeyPath:otherKeyPath]]) && ! (val == nil && [otherObject valueForKeyPath:otherKeyPath] == nil)) {
                [otherObject setValue:val forKeyPath:otherKeyPath];
            }
        }
        else {
            if((! [[object valueForKeyPath:keyPath] isEqual:[otherObject valueForKey:otherKeyPath]]) && ! (val == nil && [otherObject valueForKey:otherKeyPath] == nil)) {
                [otherObject setValue:val forKey:otherKeyPath];
            }
        }
    }
    else {
        if(otherIsKeyPath) {
            if((! [[object valueForKey:keyPath] isEqual:[otherObject valueForKeyPath:otherKeyPath]]) && ! (val == nil && [otherObject valueForKeyPath:otherKeyPath] == nil)) {
                [otherObject setValue:val forKeyPath:otherKeyPath];
            }
        }
        else {
            if((! [[object valueForKey:keyPath] isEqual:[otherObject valueForKey:otherKeyPath]]) && ! (val == nil && [otherObject valueForKey:otherKeyPath] == nil)) {
                [otherObject setValue:val forKey :otherKeyPath];
            }
        }
    }
}

- (BOOL)containsObject:(NSObject *)object {
    return self.obj1 == object || self.obj2 == object;
}

- (NSObject *)otherObject:(NSObject *)obj {
    if(obj == self.obj1) return obj1;
    else if(obj == self.obj2) return obj2;
    else return nil;
}

- (void)dealloc {
	if(self.bindingActive) [self deactivateBinding];
    self.obj1 = nil;
    self.obj2 = nil;
}

@end

@interface TransformedObjectBinding : ObjectBinding

@property (copy) SimpleBindingTransformer transformer;

- (id)initWithKeyPath:(NSString *)keyPath1 ofObj:(NSObject *)obj1 keyPath:(NSString *)keyPath2 ofObj:(NSObject *)obj2 withTransformer:(SimpleBindingTransformer)transformer;

@end

@implementation TransformedObjectBinding
@synthesize transformer;

- (id)initWithKeyPath:(NSString *)keyPath1_ ofObj:(NSObject *)obj1_ keyPath:(NSString *)keyPath2_ ofObj:(NSObject *)obj2_ withTransformer:(SimpleBindingTransformer)transformer_ {
    if((self = [super init])) {
        self.obj1 = obj1_; self.keyPath1 = keyPath1_;
        self.obj2 = obj2_; self.keyPath2 = keyPath2_;
        
        NSString *key1 = [[[self.keyPath1 componentsSeparatedByString:@"."] initialArray] componentsJoinedByString:@"."];
        if(key1 == nil || [key1 isEqualToString:@""]) key1 = self.keyPath1;
        self.isKeyPath1 = [self.obj1 valueForKeyPath:key1] != nil;
        NSString *key2 = [[[self.keyPath2 componentsSeparatedByString:@"."] initialArray] componentsJoinedByString:@"."];
        if(key2 == nil || [key2 isEqualToString:@""]) key2 = self.keyPath2;
        self.isKeyPath2 = [self.obj2 valueForKeyPath:key2] != nil;
        
        self.transformer = transformer_;
        if(self.isKeyPath1) {
            if(self.isKeyPath2)
                [self.obj1 setValue:(self.transformer([self.obj2 valueForKeyPath:self.keyPath2])) forKeyPath:self.keyPath1];
            else
                [self.obj1 setValue:(self.transformer([self.obj2 valueForKey:self.keyPath2])) forKeyPath:self.keyPath1];
        }
        if(self.isKeyPath2)
            [self.obj1 setValue:(self.transformer([self.obj2 valueForKeyPath:self.keyPath2])) forKey:self.keyPath1];
        else
            [self.obj1 setValue:(self.transformer([self.obj2 valueForKey:self.keyPath2])) forKey:self.keyPath1];
        [self.obj2 addObserver:self forKeyPath:self.keyPath2 options:0 context:NULL];
    }
    return self;
}

- (void)deactivateBinding {
    [self.obj2 removeObserver:self forKeyPath:self.keyPath2];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSAssert(object == self.obj2 && [keyPath isEqualToString:self.keyPath2], @"Error in simple bindings mechanism.");
    
    if(self.isKeyPath1) {
        id val = self.isKeyPath2 ? [object valueForKeyPath:keyPath] : [object valueForKey:keyPath];
        
        if(self.transformer)
            val = self.transformer(val);
        id oldVal = [self.obj1 valueForKeyPath:self.keyPath1];
        if(! (oldVal == val || [oldVal isEqual:val])) {
            [self.obj1 setValue:val forKeyPath:self.keyPath1];
        }
    }
    else {
        id val = self.isKeyPath2 ? [object valueForKeyPath:keyPath] : [object valueForKey:keyPath];
        
        if(self.transformer)
            val = self.transformer(val);
        id oldVal = [self.obj1 valueForKey:self.keyPath1];
        if(! (oldVal == val || [oldVal isEqual:val])) {
            [self.obj1 setValue:val forKey:self.keyPath1];
        }
    }
}


@end


@implementation NSObject (SimpleBindings)

static char bindingsKey;

- (void)bind:(NSString *)binding toKeyPath:(NSString *)keyPath ofObject:(id)object {
    // see "Associative references" in the docs for details
    NSMutableSet *bindings = objc_getAssociatedObject(self, &bindingsKey);
    if(bindings == nil) {
        bindings = [NSMutableSet new];
        objc_setAssociatedObject(self, &bindingsKey, bindings, OBJC_ASSOCIATION_RETAIN);
    }
    
    ObjectBinding *b = [[ObjectBinding alloc] initWithKeyPath:binding ofObj:self keyPath:keyPath ofObj:object];
    [bindings addObject:b];
	
}

- (void)unbindObject:(NSObject *)object {
    NSMutableSet *bindings = objc_getAssociatedObject(self, &bindingsKey);
    if(! bindings) return;
    
    NSMutableSet *bindingsToRemove = [NSMutableSet set];
    for(ObjectBinding *b in bindings) {
        if([b containsObject:object]) {
            [b deactivateBinding];
            [bindingsToRemove addObject:b];
        }
    }
    [bindings minusSet:bindingsToRemove];
}

static char transformedBindingsKey;

- (void)bind:(NSString *)binding toKeyPath:(NSString *)keyPath ofObject:(id)object withTransformer:(SimpleBindingTransformer)transformer {
    // see "Associative references" in the docs for details
    NSMutableSet *bindings = objc_getAssociatedObject(self, &transformedBindingsKey);
    if(bindings == nil) {
        bindings = [NSMutableSet new];
        objc_setAssociatedObject(self, &transformedBindingsKey, bindings, OBJC_ASSOCIATION_RETAIN);
    }
    
    TransformedObjectBinding *b = [[TransformedObjectBinding alloc] initWithKeyPath:binding ofObj:self keyPath:keyPath ofObj:object withTransformer:transformer];
    [bindings addObject:b];
    
}

- (void)unbindObjectTransformed:(NSObject *)object {
    NSMutableSet *bindings = objc_getAssociatedObject(self, &transformedBindingsKey);
    if(! bindings) return;
    
    NSMutableSet *bindingsToRemove = [NSMutableSet set];
    for(TransformedObjectBinding *b in bindings) {
        if([b containsObject:object]) {
            [b deactivateBinding];
            [bindingsToRemove addObject:b];
        }
    }
    [bindings minusSet:bindingsToRemove];
}

@end
