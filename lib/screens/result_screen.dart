
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/api_response.dart';
import '../utils.dart';
import '../widgets/ai_risk_gauge.dart';

class ResultScreen extends ConsumerWidget {
  final Response result;

  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {


    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await handleBack(context);
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20,top: 81,right: 20),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment:  MainAxisAlignment.center,
            children: [

              _AiRiskCard(result: result),

            ],
          ),
        ),
      ),
    );
  }
}

class _AiRiskCard extends StatelessWidget {
  final Response result;
  const _AiRiskCard({required this.result});


  @override
  Widget build(BuildContext context) {
    int score = (result.confidence! * 100).toInt();
    String risk;
    String output = (result.prediction! =="PD")?"has Parkinson":"doesn't have Parkinson";
    if(score > 80)
      {
        risk = "High Risk";
      }
    else if(score > 50)
      {
        risk = "moderate Risk";
      }
    else if(score > 35)
    {
      risk = "slight Risk";
    }
    else
    {
      risk = "No Risk";
    }



    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F4A43),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'AI Risk Score',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          GaugeWithCenterWidget(
            width: MediaQuery.of(context).size.width * 0.7,
            height: 300,
            progress: result.confidence!,
            strokeWidth: 30,
            backgroundColor: Colors.white,
            progressColor: const Color.fromRGBO(167, 201, 87, 1),
            centerWidget: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score/100',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(167, 201, 87, 1),
                  ),
                ),
                const SizedBox(height: 4),
                 Text(
                  risk,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('AI Result:'),
              Text(
                output,
                style: _bodyStyle,
              ),
            ],
          ),
          const SizedBox(height: 12),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Probability:'),
              Text(
                '${(result.confidence! * 100).toInt()}%',
                style: _bodyStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.teal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _sectionTitle),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}



const _sectionTitle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.bold,
  color: Color.fromRGBO(167, 201, 87, 1),
);

const _bodyStyle = TextStyle(
  fontSize: 20,
  height: 1.4,
  fontWeight: FontWeight.w400,
  color: Color.fromRGBO(242, 242, 242, 1),
);

/*
const _highlightStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.bold,
  color: Color.fromRGBO(167, 201, 87, 1),
);
*/
Text _label(String text) => Text(
  text,
  style: const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: Color.fromRGBO(94, 246, 226, 1),
  ),
);
