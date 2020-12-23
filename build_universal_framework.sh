# Note: this file is originally based upon
# https://gkbrown.org/2017/10/11/creating-a-universal-framework-in-xcode-9/
# Since it includes simulator slices as well, these will need to be
# stripped out prior to the apps being submitted to the app store

FRAMEWORK=ObjectiveRocks
BUILD=build
FRAMEWORK_NAME_WITH_EXT=$FRAMEWORK.framework
DSYM_NAME_WITH_EXT=$FRAMEWORK_NAME_WITH_EXT.dSYM

IOS_ARCHIVE_DIR=Release-iphoneos-archive
IOS_ARCHIVE_FRAMEWORK_PATH=$BUILD/$IOS_ARCHIVE_DIR/Products/Library/Frameworks/$FRAMEWORK_NAME_WITH_EXT
IOS_ARCHIVE_DSYM_PATH=$BUILD/$IOS_ARCHIVE_DIR/dSYMs
IOS_SIM_DIR=Release-iphonesimulator
IOS_UNIVERSAL_DIR=Release-universal-iOS
BUILD_FOR_MAC=false
if [ "$BUILD_FOR_MAC" = true ] ; then
  MACOS_ARCHIVE_DIR=Release-macos-archive
fi

echo "### Should also build for macOS? $BUILD_FOR_MAC"

echo "### Cleaning up after old builds"
rm -Rf $BUILD

echo "### Installing dependencies"
if ! [ -x "$(command -v xcpretty)" ]; then
  echo "Installing xcpretty....."
  gem install xcpretty
fi

# iOS
echo "### BUILDING FOR iOS"
echo "### Building for device (Archive)"
xcodebuild archive -workspace ObjectiveRocks.xcworkspace -scheme ObjectiveRocks-iOS -sdk iphoneos -archivePath $BUILD/Release-iphoneos.xcarchive OTHER_CFLAGS="-fembed-bitcode" BITCODE_GENERATION_MODE=bitcode | xcpretty
echo "### Building for simulator (Release)"
xcodebuild build -workspace ObjectiveRocks.xcworkspace -scheme ObjectiveRocks-iOS -configuration Release -sdk iphonesimulator ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO SYMROOT=$BUILD OTHER_CFLAGS="-fembed-bitcode" BITCODE_GENERATION_MODE=bitcode | xcpretty
echo "### Copying framework files"
mv $BUILD/Release-iphoneos.xcarchive $BUILD/$IOS_ARCHIVE_DIR
mkdir -p $BUILD/$IOS_UNIVERSAL_DIR
cp -RL $IOS_ARCHIVE_FRAMEWORK_PATH $BUILD/$IOS_UNIVERSAL_DIR/$FRAMEWORK_NAME_WITH_EXT
cp -RL $IOS_ARCHIVE_DSYM_PATH/$DSYM_NAME_WITH_EXT $BUILD/$IOS_UNIVERSAL_DIR/$DSYM_NAME_WITH_EXT
# if it exists, copy over the swiftmodule... no worries if not
cp -RL $BUILD/$IOS_SIM_DIR/$FRAMEWORK_NAME_WITH_EXT/Modules/$FRAMEWORK.swiftmodule/* $BUILD/$IOS_UNIVERSAL_DIR/$FRAMEWORK_NAME_WITH_EXT/Modules/$FRAMEWORK.swiftmodule
echo "### lipo'ing the iOS frameworks together into universal framework"
lipo -create $IOS_ARCHIVE_FRAMEWORK_PATH/$FRAMEWORK $BUILD/$IOS_SIM_DIR/$FRAMEWORK_NAME_WITH_EXT/$FRAMEWORK -output $BUILD/$IOS_UNIVERSAL_DIR/$FRAMEWORK_NAME_WITH_EXT/$FRAMEWORK
echo "### lipo'ing the iOS dSYMs together into a universal dSYM"
DSYM_PATH=$DSYM_NAME_WITH_EXT/Contents/Resources/DWARF/$FRAMEWORK
lipo -create $IOS_ARCHIVE_DSYM_PATH/$DSYM_PATH $BUILD/$IOS_SIM_DIR/$DSYM_PATH  -output $BUILD/$IOS_UNIVERSAL_DIR/$DSYM_PATH

if [ "$BUILD_FOR_MAC" = true ] ; then
  # macOS
  echo "### BUILDING FOR macOS"
  echo "### Building for device (Archive)"
  xcodebuild archive -workspace ObjectiveRocks.xcworkspace -scheme ObjectiveRocks -archivePath $BUILD/Release-macos.xcarchive OTHER_CFLAGS="-fembed-bitcode" BITCODE_GENERATION_MODE=bitcode | xcpretty
  mv $BUILD/Release-macos.xcarchive $BUILD/$MACOS_ARCHIVE_DIR
fi

# Rename and zip
echo "### Copying iOS files into zip directory"
ZIP_DIR=$BUILD/zip
mkdir $ZIP_DIR
cp -RL LICENSE $ZIP_DIR

mkdir $ZIP_DIR/iOS
cp -RL $BUILD/$IOS_UNIVERSAL_DIR/$FRAMEWORK_NAME_WITH_EXT $ZIP_DIR/iOS/$FRAMEWORK_NAME_WITH_EXT
cp -RL $BUILD/$IOS_UNIVERSAL_DIR/$DSYM_NAME_WITH_EXT $ZIP_DIR/iOS/$DSYM_NAME_WITH_EXT

if [ "$BUILD_FOR_MAC" = true ] ; then
  echo "### Copying macOS files into zip directory"
  mkdir $ZIP_DIR/macOS
  cp -RL $BUILD/$MACOS_ARCHIVE_DIR/Products/Library/Frameworks/$FRAMEWORK_NAME_WITH_EXT $ZIP_DIR/macOS/$FRAMEWORK_NAME_WITH_EXT
  cp -RL $BUILD/$MACOS_ARCHIVE_DIR/dSYMs/$DSYM_NAME_WITH_EXT $ZIP_DIR/macOS/$DSYM_NAME_WITH_EXT
fi

cd $ZIP_DIR
if [ "$BUILD_FOR_MAC" = true ] ; then
  zip -r ObjectiveRocks.zip LICENSE iOS/$FRAMEWORK_NAME_WITH_EXT iOS/$DSYM_NAME_WITH_EXT macOS/$FRAMEWORK_NAME_WITH_EXT macOS/$DSYM_NAME_WITH_EXT
else
  zip -r ObjectiveRocks.zip LICENSE iOS/$FRAMEWORK_NAME_WITH_EXT iOS/$DSYM_NAME_WITH_EXT
fi
echo "### Zipped resulting frameworks and dSYMs to $ZIP_DIR/ObjectiveRocks.zip"
