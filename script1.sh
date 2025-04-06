#!/bin/bash
# Директория для хранения резервных копий на основном узле
LOCAL_BACKUP_DIR="/var/db/postgres0/backups/$(date +%Y-%m-%d_%H-%M-%S)"
# Директория для хранения резервных копий на резервном узле
REMOTE_BACKUP_DIR="/var/db/postgres1/backups/$(date +%Y-%m-%d_%H-%M-%S)"
# Создание директории на основном узле
mkdir -p $LOCAL_BACKUP_DIR
# Создание директории на резервном узле
ssh postgres1@pg114 "mkdir -p $REMOTE_BACKUP_DIR"

# Выполнение резервного копирования на основном узле
pg_basebackup -D $LOCAL_BACKUP_DIR -Ft -z -Xs -P -U replicator -h pg109 -p 9455
# Проверка успешности выполнения
if [ $? -eq 0 ]; then
  echo "Резервное копирование успешно завершено на основном узле: $LOCAL_BACKUP_DIR"
  # Копирование резервной копии на резервный узел
  scp -r $LOCAL_BACKUP_DIR/* postgres1@pg114:$REMOTE_BACKUP_DIR/
  # Проверка успешности копирования
  if [ $? -eq 0 ]; then
    echo "Резервная копия успешно перенесена на резервный узел: $REMOTE_BACKUP_DIR"
    # Удаление старых резервных копий на основном узле (старше 1 недели)
    find /var/db/postgres0/backups -type d -mtime +7 -exec rm -rf {} \;
    echo "Старые резервные копии удалены на основном узле"
    # Удаление старых резервных копий на резервном узле (старше 4 недель)
    ssh postgres1@pg114 "find /var/db/postgres1/backups -type d -mtime +28 -exec rm -rf {} \;"
    echo "Старые резервные копии удалены на резервном узле"
  else
    echo "Ошибка при переносе резервной копии на резервный узел"
    exit 1
  fi
else
  echo "Ошибка при выполнении резервного копирования на основном узле"
  exit 1
fi
