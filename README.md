# TITS - Time Interval Thinning System

# Installation

```
gem tits, :git => 'git@gitlab.gobi.tzi.de:gobi/gem-tits.git'
```

# Einbindung

```ruby
require 'tits'
```

# Benötigte Models

## Resource
Ein beliebig benanntes ActiveRecord-Model kann für die Verwendung mit TITS genutzt werden.
Die einzigen Voraussetzungen:

* Ein Attribut `id` (das schon allein durch ActiveRecord ohnehin vorhanden ist)
* Erben von TITS::Base statt ActiveRecord::Base

```ruby
class Resource < TITS::Base
  
  [...]
end
```

Dieses Model kann beliebig viele Attribute und Beziehungen haben und wird wie gehabt in der ActiveRecord-DB gespeichert.

## Measurement

TITS liefert sein eigenes Model `Measurement` mit (das streng genommen kein ActiveRecord-Model ist, sondern einfach nur ein Datentyp). Die Measurements werden nicht in der ActiveRecord-DB, sondern in der InfluxDB gespeichert.

# Config

In `config/config.yml` wird die Datenbankverbindung konfiguriert. Voreingestellt ist die InfluxDB-Sandbox. TODO: Ersetzen durch InfluxDB auf Richard.

# Verwendung / Beispiel

Annahme: r ist eine Resource.

```ruby
r = Resource.create(name: 'my_temp_1', resource_type: 'temp', path: 'some/path/wow')
```

### Generelles

* Zeiten werden als Ruby Time-Objekt erwartet.

* Die Angabe eines Zeitraums ist immer optional. Fehlt sie, geht TITS vom Zeitraum "Jahr 0 bis jetzt" aus. Es kann auch nur eine der beiden Angaben übergeben werden.

* Die Granularität beeinflusst die Granularität der zurückgegebenen Werte. Akzeptiert werden Sekunden als Float. Empfehlenswert ist die Verwendung von Ruby-Helpern wie 1.month oder 3.days.

* Genaueres zu Parametern und Rückgabewerten findet sich auch in der yardoc-Dokumentation.

### Messwert hinzufuegen

```ruby
r.add_measurement 29.3, Time.now
```

### Observer

Es kann ein Block festgelegt werden, der immer ausgeführt wird, wenn ein neuer Wert hinzugefügt wird.
Diesem Block steht dann ein `MeasurementDTO`-Objekt zur Verfügung, das Zeit, Wert und Resource-ID enthält.

```ruby
TITS.on_write { |dto|
  puts "New value #{dto.value} has been added at #{dto.time}."
  # Oder auch: WebsocketRails[:measurements].trigger 'new', dto
}
```

Dieser Block wird einmalig festgelegt, kann aber natürlich auch zwischendurch geändert werden.
Wird kein Block gesetzt, wird eine neue Messung trotzdem in die InfluxDB eingetragen, aber nichts weiter.

### Aktueller Wert

Fragt den letzten Wert ab.

```ruby
puts "Current value #{r.current_measurement.value}."
=> Current value 25.5.
```

### Dichtester Wert

Versucht einen Wert in einem Zeitraum von 10 Minuten um einen angegebenen Zeitpunkt zu finden. Nimmt dann den dichtesten Wert oder nil, wenn keiner existiert.

```ruby
t = Time.new(2013, 11, 12, 2, 16, 00)
puts "Closest value at #{t}: #{r.measurement(t).value}."
=> Closest value at 2013-11-12 02:16:00 +0100: 25.5.
```

### Werte aus einem Zeitraum

Liefert ein Array mit allen Werten im angebenen Zeitraum zurück.

```ruby
t1 = Time.new(2013, 11, 10, 2, 10, 31)
t2 = Time.new(2013, 11, 12, 2, 10, 24)
puts "All values between #{t1} and #{t2}: #{r.measurements(start_point: t1, end_point: t2)}."
=> All values between 2013-11-10 02:10:31 +0100 and 2013-11-12 02:10:24 +0100: [die ganzen Measurement-Objekte]. 
```

### Maximum, Minimum, Durchschnitt

Liefert Maximum, Minimum bzw. Durchschnitt aus einem Zeitraum.

```ruby
puts "Maximum value: #{r.max_measurement.value}."
=> Maximum value: 25.5.

puts "Minimum value: #{r.min_measurement(start_point: 1.year.ago, end_point: Time.now).value}."
=> Minimum value: 19.5.

puts "Average value: #{r.avg_measurement(start_point: 1.year.ago, end_point: Time.now).value}."
=> Average value: 22.5.
```

### Löschen von Measurements

Löschen aller Measurements einer Ressource (in der InfluxDB Series genannt) über die Ressource selbst:

```ruby
r.delete_series
```

Löschen aller Measurements einer Resource "von außen":

```ruby
TITS.delete_series some_resource_id
```

Löschen der ganzen Datenbank:
(Kann nur als InfluxDB-Admin ausgeführt werden!)

```ruby
TITS.delete_db
```

## Rake-Tasks

Neben den Standard-Tasks gibt es auch Tasks zum Löschen von Measurements bzw. der ganzen Datenbank:

```ruby
rake delete:series[some_resource_id]
rake delete:db
```

Diese Taks finden sich zum einen in der Rakefile des TITS-Gems, zum anderen auch in tits_delete.rake. Kann in der Zentrale bzw. im Webinterface einfach in den Ordner lib/taks kopiert werden, dann stehen die Tasks auch da direkt zur Verfügung.

Mehrere Measurements in einer einzigen Abfrage
-----------------------------------------------------------------------

Um wiederholte Anfragen an die InfluxDB aus Performanzgründen zu vermeiden, können die letzten Measurements mehrerer Ressourcen auf einmal abgefragt werden.

```ruby
# IDs der gewünschten Ressourcen als Array von Integern.
TITS.multi_current_measurements([1340, 5555])
# => Ein Array mit jeweils der letzten Messung der Ressource mit der ID 1340 sowie der Ressource mit der ID 5555.

# Auch einzelne IDs sind möglich (wenn auch weniger sinnvoll):
TITS.multi_current_measurements(1500)
# => Die letzte Messung der Ressource mit der ID 1500 (als Array mit einem Element).

# Die Methode kann auch ohne Argumente aufgerufen werden:
TITS.multi_current_measurements
# => Ein Array mit der jeweils letzten Messung ALLER Ressourcen.
```