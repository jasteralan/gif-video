var gulp = require('gulp');
var coffee 		= require('gulp-coffee'),
	livereload 	= require('gulp-livereload'),
	plumber 	= require('gulp-plumber'),
	growl   	= require('gulp-notify-growl'),
	growlNotifier = growl(),
	concat 	= require('gulp-concat'),
	uglify 	= require('gulp-uglify');

var paths = {
	scss 	: 'scss/**/*.scss',
	scripts : 'coffee/**/*.coffee',
  	images  : 'imgo/**/*',
  	jspaths : ['js/jsgif.js', 'js/gifvideo.js']
};

gulp.task('scripts', function(){
	return gulp.src(paths.scripts)
		.pipe(plumber())
		.pipe(coffee())
		.pipe(gulp.dest('js'))
		.pipe(livereload())
		.pipe(growlNotifier({
    		title  : 'Coffee',
    		message: 'Compiled complete'
  		}));
});

gulp.task('jsminify', function(){
	return gulp.src(paths.jspaths)
		.pipe(uglify())
		.pipe(concat('gifvideo.min.js'))
		.pipe(gulp.dest('js'));
});

gulp.task('watch', function() {
  	gulp.watch(paths.scripts,['scripts']);  
});

gulp.task('default', ['scripts', 'watch']);