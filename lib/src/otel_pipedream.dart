// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_pipedream_suppression.dart';

const _tracerName = 'dartastic_otel_libs_pipedream';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class PipedreamResult {
  const PipedreamResult({
    this.workspaceId,
    this.workflowId,
    this.sourceId,
    this.eventId,
    this.componentKey,
    this.triggerType,
    this.eventStatus,
    this.creditsCharged,
    this.durationMs,
    this.memoryMb,
    this.warmStart,
    this.statusCode,
  });

  final String? workspaceId;
  final String? workflowId;
  final String? sourceId;
  final String? eventId;

  /// Registry component (e.g., `slack-send-message`).
  final String? componentKey;

  /// `http` / `cron` / `email` / `webhook` / `app_event` / `manual`.
  final String? triggerType;

  /// `success` / `error` / `cancelled` / `timeout`.
  final String? eventStatus;

  /// Pipedream pricing unit — workflow seconds get rounded up into
  /// credits. Critical for cost tracking.
  final int? creditsCharged;

  final int? durationMs;
  final int? memoryMb;

  /// `true` when the workflow ran on a warm worker (cheaper, faster).
  final bool? warmStart;

  final int? statusCode;
}

class PipedreamCallResult<T> {
  const PipedreamCallResult({required this.value, this.result});
  final T value;
  final PipedreamResult? result;
}

/// Wraps a Pipedream API call in a CLIENT span. [operation] is one of
/// `workflows.trigger`, `workflows.deploy`, `events.list`,
/// `sources.create`, `sources.delete`, `components.run`,
/// `accounts.list`.
Future<T> tracedPipedream<T>({
  required String operation,
  required Future<PipedreamCallResult<T>> Function() invoke,
}) async {
  if (pipedreamInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'pipedream',
    'rpc.method': operation,
    'pipedream.operation': operation,
  };

  final span = _tracer().startSpan(
    'pipedream $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.workspaceId != null) {
        extras.add(OTel.attributeString(
          'pipedream.workspace.id',
          r.result!.workspaceId!,
        ));
      }
      if (r.result!.workflowId != null) {
        extras.add(OTel.attributeString(
          'pipedream.workflow.id',
          r.result!.workflowId!,
        ));
      }
      if (r.result!.sourceId != null) {
        extras.add(OTel.attributeString(
          'pipedream.source.id',
          r.result!.sourceId!,
        ));
      }
      if (r.result!.eventId != null) {
        extras.add(OTel.attributeString(
          'pipedream.event.id',
          r.result!.eventId!,
        ));
      }
      if (r.result!.componentKey != null) {
        extras.add(OTel.attributeString(
          'pipedream.component.key',
          r.result!.componentKey!,
        ));
      }
      if (r.result!.triggerType != null) {
        extras.add(OTel.attributeString(
          'pipedream.trigger.type',
          r.result!.triggerType!,
        ));
      }
      if (r.result!.eventStatus != null) {
        extras.add(OTel.attributeString(
          'pipedream.event.status',
          r.result!.eventStatus!,
        ));
        if (r.result!.eventStatus == 'error' ||
            r.result!.eventStatus == 'timeout') {
          span.setStatus(
            SpanStatusCode.Error,
            'Pipedream event ${r.result!.eventStatus}',
          );
        }
      }
      if (r.result!.creditsCharged != null) {
        extras.add(OTel.attributeInt(
          'pipedream.credits.charged',
          r.result!.creditsCharged!,
        ));
      }
      if (r.result!.durationMs != null) {
        extras.add(OTel.attributeInt(
          'pipedream.duration_ms',
          r.result!.durationMs!,
        ));
      }
      if (r.result!.memoryMb != null) {
        extras.add(OTel.attributeInt(
          'pipedream.memory_mb',
          r.result!.memoryMb!,
        ));
      }
      if (r.result!.warmStart != null) {
        extras.add(OTel.attributeBool(
          'pipedream.warm_start',
          r.result!.warmStart!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Pipedream HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
