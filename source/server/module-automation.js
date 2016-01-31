Space.Module.mixin({

  routers: [],
  projections: [],

  onDependenciesReady: function() {
    this._wrapLifecycleHook('onInitialize', this._onInitializeEventSourcing);
    this._wrapLifecycleHook('onStart', this._onStartEventSourcing);
  },

  _onInitializeEventSourcing: function(onInitialize) {
    const module = this;
    onInitialize.call(module);
    _.each(_.union(module.routers, module.projections), function(singleton) {
      module.injector.map(singleton).asSingleton();
    });
  },

  _onStartEventSourcing: function(onStart) {
    const module = this;
    onStart.call(module);
    _.each(_.union(module.routers, module.projections), function(singleton) {
      module.injector.create(singleton);
    });
  }

});
