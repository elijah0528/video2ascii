import Video2Ascii from "../src/components/VideoToAscii";

const App = () => {
    return (
        <div className="max-w-4xl mx-auto p-8">
            <h1 className="text-2xl font-bold mb-8 text-white">Video2Ascii</h1>

            {/* Video Examples */}
            <section className="mb-12">
                <div className="mb-8">
                    <h3 className="font-semibold mb-2 text-white">Basic Video with Mouse Trail</h3>
                    <div className="rounded overflow-hidden">
                        <Video2Ascii
                            src="/hummingbird.mp4"
                            mediaType="video"
                            numColumns={100}
                            colored={true}
                            autoPlay={true}
                            enableMouse={true}
                            trailLength={20}
                            showStats={true}
                        />
                    </div>
                </div>

                <div className="mb-8">
                    <h3 className="font-semibold mb-2 text-white">Video with Ripple Effect</h3>
                    <div className="rounded overflow-hidden">
                        <Video2Ascii
                            src="/parrots.mp4"
                            mediaType="video"
                            numColumns={120}
                            colored={true}
                            autoPlay={true}
                            enableRipple={true}
                            rippleSpeed={30}
                            showStats={true}
                        />
                    </div>
                </div>
            </section>

            {/* Image Examples */}
            <section>
                <div className="mb-8">
                    <h3 className="font-semibold mb-2 text-white">Basic Image to ASCII</h3>
                    <p className="text-gray-400 mb-2 text-sm">Converting a static image with colored output</p>
                    <div className="rounded overflow-hidden">
                        <Video2Ascii
                            src="https://picsum.photos/800/600"
                            mediaType="image"
                            numColumns={120}
                            colored={true}
                            showStats={true}
                        />
                    </div>
                </div>

                <div className="mb-8">
                    <h3 className="font-semibold mb-2 text-white">Image with Mouse Effects</h3>
                    <p className="text-gray-400 mb-2 text-sm">Move your mouse over the image</p>
                    <div className="rounded overflow-hidden">
                        <Video2Ascii
                            src="https://picsum.photos/id/237/800/600"
                            mediaType="image"
                            numColumns={100}
                            colored={true}
                            enableMouse={true}
                            trailLength={20}
                            showStats={true}
                        />
                    </div>
                </div>
            </section>
        </div>
    );
};

export default App;
