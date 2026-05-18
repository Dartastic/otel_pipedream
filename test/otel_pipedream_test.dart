// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_pipedream/otel_pipedream.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_pipedream-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('workflows.trigger records workflow + credits + duration', () async {
    await tracedPipedream<String>(
      operation: 'workflows.trigger',
      invoke: () async => const PipedreamCallResult(
        value: 'ok',
        result: PipedreamResult(
          workspaceId: 'ws_1',
          workflowId: 'wf_1',
          triggerType: 'http',
          eventStatus: 'success',
          creditsCharged: 2,
          durationMs: 1500,
          memoryMb: 256,
          warmStart: true,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('pipedream workflows.trigger')!);
    expect(a['pipedream.workflow.id'], 'wf_1');
    expect(a['pipedream.trigger.type'], 'http');
    expect(a['pipedream.credits.charged'], 2);
    expect(a['pipedream.duration_ms'], 1500);
    expect(a['pipedream.warm_start'], true);
  });

  test('timeout event sets span error', () async {
    await tracedPipedream<String>(
      operation: 'workflows.trigger',
      invoke: () async => const PipedreamCallResult(
        value: 'ok',
        result: PipedreamResult(eventStatus: 'timeout', creditsCharged: 30),
      ),
    );
    expect(
      spans.findSpanByName('pipedream workflows.trigger')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutPipedreamInstrumentationAsync(() async {
      await tracedPipedream<String>(
        operation: 'sources.create',
        invoke: () async => const PipedreamCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('pipedream '), isEmpty);
  });
}
