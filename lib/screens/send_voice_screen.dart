import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/api_response.dart';
import '../services/api.dart';
import '../utils.dart';
import '../view_models/voice_upload_view_model.dart';
import '../widgets/uploading_loading.dart';

enum FileType{
  voice,
  image

}

class SendVoiceScreen extends ConsumerStatefulWidget {
  final String filePath;
  final  FileType type;

  const SendVoiceScreen({super.key, required this.filePath, required this.type});

  @override
  ConsumerState<SendVoiceScreen> createState() => _SendVoiceScreenState();
}

class _SendVoiceScreenState extends ConsumerState<SendVoiceScreen> {
  @override
  void initState() {
    super.initState();

    // Start upload
    Future.microtask(() {

      ref.read(voiceUploadViewModelProvider.notifier).upload(
      path: widget.filePath,
      uploadFunction: (widget.type == FileType.voice) ? Api.sendVoice : Api.sendImage,
    );
    });


  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceUploadViewModelProvider);
    // Listen for state changes
    ref.listen<AsyncValue<Response?>>(
      voiceUploadViewModelProvider,
      (previous, next) {
        next.whenOrNull(
          data: (result) {
            if (result == null) return;

            switch (result.status) {
              case JobStatus.success:
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.analyezedSuccessfully),duration: const Duration(seconds: 2),),
                );

                context.go('/results', extra: result);
                break;

              case JobStatus.error:
                ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(
                    content: Text(///todo: mkae the api send and receive the language of the user so that the message be in the correct language
                      result.message??AppLocalizations.of(context)!.uploadFailed,// if there is no result.message that means the response code isn't 500 so it is another error from the api, 500 means the error from the ai
                    ),
                    duration: Duration(seconds: 4),
                  ),
                );
                context.go('/');
                break;
            }
          },
          error: (e, _) {
            if (kDebugMode) {
              print(e);
            }
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                content: Text( //

                  AppLocalizations.of(context)!.errorOccured,
                ),
                duration: Duration(seconds: 4),
              ),
            );
            context.go('/');
          },
        );
      },
    );


    return state.isLoading || state.value == null
          ? PopScope(
      canPop: false,
      onPopInvokedWithResult: (didpop,_) async{
        if(!didpop)
        {

          await handleBack(context);
        }

      },
            child:  Center(
                    child: CircularLoadingIndicator(text: AppLocalizations.of(context)!.uploadingLoading,),
                  ),
          )
          : const SizedBox.shrink();
  }
}
