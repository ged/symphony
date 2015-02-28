# Upgrading

## From 0.8.x to 0.9.0

This version introduces several new mechanisms for adjusting your workers to handle increased amounts of work.

This is accomplished via a new (backward-compatible) `tasks` config syntax, and a pluggable "work model" that can be set to control how workers running a particular task behave.

Tasks are now run inside of a "task group" which contains the logic of the work model. There are two initial work models that come with Symphony: `longlived` and `oneshot`.

The `longlived` work model is the default, and works similarly to how tasks worked prior to the 0.9 release: it starts up and executes tasks as they arrive, and then shuts down when the Symphony daemon shuts down. If you keep your configuration the same as it was before this release, nothing should change.

However, you can now tell your `longlived` task groups to automatically scale up the number of instances when the amount of work to be done increases. You can do this by converting the `tasks` config section to a Hash, with the task names as the keys and an integer as the value.

The old way:

    symphony:
      tasks:
      - audit_logger
      - failure_logger
      - payments_processor
      - user_mailer
      - thumbnailer

the new way:

    symphony:
      tasks:
        audit_logger: 1
        failure_logger: 1
        payments_processor: 1
        user_mailer: 2
        thumbnailer: 5

The value controls the _maximum_ number of that task class that can be running at one time, and the Symphony daemon will now scale the number of workers up to your specified maximum when the amount of work is trending upwards, and scale it back down to a single worker when work is trending down.

The `oneshot` work model is a new kind of worker that fetches and executes a single task and then exits. It's used for tasks that consume large amounts of memory or other resources that may not be released in between tasks such as 3D rendering or video-processing. 

