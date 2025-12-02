{{- define "ecommerce-platform.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ecommerce-platform.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default (printf "%s-sa" (include "ecommerce-platform.fullname" .)) .Values.serviceAccount.name }}
{{- else -}}
default
{{- end -}}
{{- end -}}

