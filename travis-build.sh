#!/bin/bash
set -e
rm -rf *.zip
./gradlew clean check assemble

filename=$(find build/libs -name "*.jar" | head -1)
filename=$(basename "$filename")

EXIT_STATUS=0
echo "Publishing archives for branch $TRAVIS_BRANCH"
if [[ -n $TRAVIS_TAG ]] || [[ $TRAVIS_BRANCH == 'master' && $TRAVIS_PULL_REQUEST == 'false' ]]; then

  echo "Publishing archives"

  if [[ -n $TRAVIS_TAG ]]; then
      echo "Publishing to Bintray.."
      ./gradlew audit-logging:bintrayUpload || EXIT_STATUS=$?
  else
      echo "Publishing to Grails Artifactory"
      ./gradlew audit-logging:publish || EXIT_STATUS=$?
  fi

  ./gradlew docs || EXIT_STATUS=$?

  # taken from cache plugin
  
  git config --global user.name "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
  git config --global credential.helper "store --file=~/.git-credentials"
  echo "https://$GH_TOKEN:@github.com" > ~/.git-credentials

  echo "Updating gh-pages branch..."
  git clone https://${GH_TOKEN}@github.com/${TRAVIS_REPO_SLUG}.git -b gh-pages gh-pages --single-branch > /dev/null
  cd gh-pages

  echo "Path: `pwd` . Parent audit-logging dir:"
  ls ../audit-logging/

  # If this is the master branch then update the snapshot
  if [[ $TRAVIS_BRANCH == 'master' ]]; then
    mkdir -p snapshot
    cp -r ../audit-logging/build/docs/manual/. ./snapshot/

    git add snapshot/*
  fi

    # If there is a tag present then this becomes the latest
    if [[ -n $TRAVIS_TAG ]]; then
        mkdir -p latest
        cp -r ../build/docs/manual/. ./latest/
        git add latest/*

        version="$TRAVIS_TAG"
        version=${version:1}
        majorVersion=${version:0:4}
        majorVersion="${majorVersion}x"

        mkdir -p "$version"
        cp -r ../build/docs/manual/. "./$version/"
        git add "$version/*"

        mkdir -p "$majorVersion"
        cp -r ../build/docs/manual/. "./$majorVersion/"
        git add "$majorVersion/*"

    fi

    git commit -a -m "Updating docs for Travis build: https://travis-ci.org/$TRAVIS_REPO_SLUG/builds/$TRAVIS_BUILD_ID"
    git push origin HEAD
    cd ..
    rm -rf gh-pages
fi
exit $EXIT_STATUS