import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../notifiers/voice_upload_notifier.dart';
import '../utils.dart';
import '../widgets/uploading_loading.dart';

class SendVoiceScreen extends ConsumerStatefulWidget {
  final String wavPath;

  const SendVoiceScreen({super.key, required this.wavPath});

  @override
  ConsumerState<SendVoiceScreen> createState() => _SendVoiceScreenState();
}

class _SendVoiceScreenState extends ConsumerState<SendVoiceScreen> {
  @override
  void initState() {
    super.initState();

    // Start upload
    Future.microtask(() {
      ref.read(voiceUploadProvider.notifier).upload(widget.wavPath);
    });


  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceUploadProvider);
    // Listen for state changes
    ref.listen<AsyncValue<VoiceResponse?>>(
      voiceUploadProvider,
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
