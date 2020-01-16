/*global dashboard*/
import libraryParser from './libraryParser';
import annotationList from '@cdo/apps/acemode/annotationList';

export function load(clientApi, onCodeError, onMissingFunctions, onSuccess) {
  var error = annotationList.getJSLintAnnotations().find(annotation => {
    return annotation.type === 'error';
  });

  if (error) {
    onCodeError();
    return;
  }

  let projectName = dashboard.project.getLevelName();
  let sourceAndHtml, publishedLibrary;

  let getSource = new Promise((resolve, reject) => {
    dashboard.project.getUpdatedSourceAndHtml_(response => {
      sourceAndHtml = response;
      resolve();
    });
  });

  let getLibrary = new Promise((resolve, reject) => {
    clientApi.fetchLatest(
      data => {
        publishedLibrary = JSON.parse(data);
        resolve();
      },
      error => {
        resolve();
      }
    );
  });

  Promise.all([getSource, getLibrary]).then(() => {
    let functionsList = libraryParser.getFunctions(sourceAndHtml.source);
    if (!functionsList || functionsList.length === 0) {
      onMissingFunctions();
      return;
    }
    let librarySource = sourceAndHtml.source;
    if (sourceAndHtml.libraries) {
      sourceAndHtml.libraries.forEach(library => {
        librarySource =
          libraryParser.createLibraryClosure(library) + librarySource;
      });
    }

    let description = '';
    let selectedFunctions = {};
    let alreadyPublished = false;
    if (publishedLibrary) {
      alreadyPublished = true;
      description = publishedLibrary.description;
      projectName = publishedLibrary.name;
      publishedLibrary.functions.forEach(publishedFunction => {
        if (
          functionsList.find(
            projectFunction =>
              projectFunction.functionName === publishedFunction
          )
        ) {
          selectedFunctions[publishedFunction] = true;
        }
      });
    }

    onSuccess({
      libraryName: projectName,
      libraryDescription: description,
      librarySource: librarySource,
      sourceFunctionList: functionsList,
      selectedFunctions: selectedFunctions,
      alreadyPublished: alreadyPublished
    });
  });
}

export default {
  load
};
