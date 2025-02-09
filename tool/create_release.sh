# Ensures that the package is ready for a release.
# 
# Will update the pubspec.yaml and update the CHANGELOG.md.
#
# Run in current directory with existing version
# `./tool/create_release.sh`
#
# Try and run with new version
# `./tool/create_release.sh <version>

# Check if current directory has a pubspec.yaml, if so we assume it is correctly set up.
if [ ! -f "pubspec.yaml" ]; then
    echo "$(pwd) is not a valid package, missing pubspec.yaml."
    exit 1
fi

currentBranch=$(git symbolic-ref --short -q HEAD)
if [[ ! $currentBranch == "main" ]]; then
    echo "Releasing is only supported on the main branch."
    exit 1
fi

# Get package version
package_version=$(dart pub deps --json | pcregrep -o1 -i '"version": "(.*?)"' | head -1)

# Get new version
new_version="";
if [ "$1" != "" ]; then
  new_version="$1";
else
  new_version="$(dart pub deps --json | pcregrep -o1 -i '"version": "(.*?)"' | head -1)";
fi

if [[ "$new_version" == "$package_version" ]]; then
  echo "Current version is $package_version, can't update."
  exit 0
fi

# Retrieving all the commits in the current directory since the last tag.
previousTag="$v${package_version}"
raw_commits="$(git log --pretty=format:"%s" --no-merges --reverse $previousTag..HEAD -- .)"
markdown_commits=$(echo "$raw_commits" | sed -En "s/\(#([0-9]+)\)/([#\1](https:\/\/github.com\/wolfenrain\/fluttium\/issues\/\1))/p")

if [[ "$markdown_commits" == "" ]]; then
  echo "No commits since last tag, can't update."
  exit 0
fi
commits=$(echo "$markdown_commits" | sed -En "s/^/- /p")

echo "Updating version to $new_version"
sed -i '' "s/version: $package_version/version: $new_version/g" pubspec.yaml

if grep -q $new_version "CHANGELOG.md"; then
    echo "CHANGELOG already contains version $new_version."
    exit 1
fi

# Add a new version entry with the found commits to the CHANGELOG.md.
echo "# ${new_version}\n\n${commits}\n\n$(cat CHANGELOG.md)" > CHANGELOG.md
echo "CHANGELOG generated, validate entries here: $(pwd)/CHANGELOG.md"

echo "Creating git branch for $new_version"
git checkout -b "chore/$new_version" > /dev/null

git add pubspec.yaml CHANGELOG.md

echo ""
echo "Run the following command if you wish to commit the changes:"
echo "git commit -m \"chore: $new_version\""