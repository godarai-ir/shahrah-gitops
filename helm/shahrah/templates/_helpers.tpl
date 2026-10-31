{{- define "shahrah.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "shahrah.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "shahrah.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "shahrah.labels" -}}
helm.sh/chart: {{ include "shahrah.chart" . }}
app.kubernetes.io/name: {{ include "shahrah.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "shahrah.selectorLabels" -}}
app.kubernetes.io/name: {{ include "shahrah.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "shahrah.workloads" -}}
{{- dict
  "control-plane" .Values.controlPlane
  "model-discovery" .Values.modelDiscovery
  "model-discovery-web" .Values.modelDiscoveryWeb
  "support-admin" .Values.supportAdmin
  "silk-road" .Values.silkRoad
  "tenant-admin" .Values.tenantAdmin
  "librechat" .Values.librechat
  "website" .Values.website
  "blog" .Values.blog
  "docs" .Values.docs
-}}
{{- end -}}

{{/*
Migration hook images. Shared by migrate-jobs.yaml and migration-images-configmap.yaml
so the tracked ConfigMap always changes when a hook's image changes.
*/}}
{{- define "shahrah.migrations.mainDbImage" -}}
{{ .Values.global.imageRegistry }}/{{ .Values.migrations.mainDb.image.repository }}:goose-{{ .Values.migrations.mainDb.image.tag | default .Values.global.imageTag }}
{{- end -}}

{{- define "shahrah.migrations.supportAdminImage" -}}
{{ .Values.global.imageRegistry }}/{{ .Values.migrations.supportAdmin.image.repository }}:support-admin-migrate-{{ .Values.migrations.supportAdmin.image.tag | default .Values.global.imageTag }}
{{- end -}}

{{- define "shahrah.migrations.clickhouseImage" -}}
{{ .Values.migrations.clickhouse.image.repository }}:{{ .Values.migrations.clickhouse.image.tag }}
{{- end -}}

{{- define "shahrah.migrations.modelDiscoveryImage" -}}
{{ .Values.global.imageRegistry }}/{{ .Values.migrations.modelDiscovery.image.repository }}:model-discovery-migrate-{{ .Values.migrations.modelDiscovery.image.tag | default .Values.global.imageTag }}
{{- end -}}

{{- define "shahrah.migrations.modelDiscoveryCatalogImportImage" -}}
{{- $catalogImport := .Values.migrations.modelDiscoveryCatalogImport -}}
{{ .Values.global.imageRegistry }}/{{ $catalogImport.image.repository | default .Values.migrations.modelDiscovery.image.repository }}:model-discovery-migrate-{{ $catalogImport.image.tag | default .Values.migrations.modelDiscovery.image.tag | default .Values.global.imageTag }}
{{- end -}}
