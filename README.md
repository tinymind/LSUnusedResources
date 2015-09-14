# LSUnusedResources
A Mac App to find unused images and resources in an XCode project. It is heavily influenced by jeffhodnett‘s [Unused](http://jeffhodnett.github.io/Unused/), but Unused is very slow, and the results are not entirely correct. So I made some performance optimization, the search speed is more faster than Unused.

## Example

![LSMessageHUD Example1](https://github.com/tinymind/LSUnusedResources/raw/master/LSUnusedResourcesExample.gif)  

## Usage

It's an useful utility tool to check what resources are not being used in your Xcode projects. Very easy to use: 

1. Click `Browse..` to select a project folder.
2. Click `Search` to start searching.
3. Wait a second, the results will be shown in the tableview.

## Feature

Check `Ignore similar name` to ignore the resources which referenced by string concatenation.

For example:

You import some resources like:

```
icon_tag_0.png
icon_tag_1.png
icon_tag_2.png
icon_tag_3.png
```

And using in this way:

```
	NSInteger index = random() % 4;
	UIImage *img = [UIImage imageNamed:[NSString stringWithFormat:@"icon_tag_%d", index]];
```

`icon_tag_x.png` should not be shown as unused resource, we should ignore them.

## Installation

* Download: [LSUnusedResources.app.zip](https://github.com/tinymind/LSUnusedResources/raw/master/Release/LSUnusedResources.app.zip)
* Or build and run the project using XCode.

## Requirements

Requires OS X 10.7 and above, ARC.
